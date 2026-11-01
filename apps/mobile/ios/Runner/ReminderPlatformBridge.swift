import Flutter
import UIKit
import UserNotifications
import VerdiNative

final class SystemReminderCenter: ReminderCenter {
  let center=UNUserNotificationCenter.current()
  func authorization() async throws -> String {
    let settings=await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined:return "notDetermined"
    case .denied:return "denied"
    case .authorized:return "authorized"
    case .provisional:return "provisional"
    default:throw PigeonError(code:"NOT_AVAILABLE",message:nil,details:nil)
    }
  }
  func requestAuthorization() async throws -> String {
    _ = try await center.requestAuthorization(options:[.alert,.sound])
    return try await authorization()
  }
  func pending() async throws -> [String] {await center.pendingNotificationRequests().map(\.identifier)}
  func delivered() async throws -> [String] {await center.deliveredNotifications().map{$0.request.identifier}}
  func remove(pending:[String],delivered:[String]) async throws {
    center.removePendingNotificationRequests(withIdentifiers:pending)
    center.removeDeliveredNotifications(withIdentifiers:delivered)
  }
  func add(_ request:ReminderRequest) async throws {
    let content=UNMutableNotificationContent()
    content.title=NSString.localizedUserNotificationString(forKey:"Plant-care checks",arguments:nil)
    content.body=NSString.localizedUserNotificationString(forKey:request.count==1 ? "A plant-care check to review" : "%ld plant-care checks to review",arguments:request.count==1 ? nil:[NSNumber(value:request.count)])
    content.sound = .default
    guard let payload=try JSONSerialization.jsonObject(with:Data(request.payloadJSON.utf8)) as? [String:Any] else{throw PigeonError(code:"INVALID_PAYLOAD",message:nil,details:nil)}
    content.userInfo=payload
    // Resolve DST/wall-clock once in the planner; an absolute UTC trigger avoids
    // reinterpreting the second occurrence of a repeated local clock time.
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
    var components=calendar.dateComponents([.year,.month,.day,.hour,.minute,.second],from:request.fireAt)
    components.calendar=calendar;components.timeZone=calendar.timeZone
    try await center.add(UNNotificationRequest(identifier:request.identifier,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false)))
  }
}

@MainActor
final class ReminderPlatformBridge:NSObject,ReminderPlatformHostApi,UNUserNotificationCenterDelegate {
  let coordinator:ReminderCoordinator
  private var observers:[NSObjectProtocol]=[]
  private var events:ReminderPlatformEventsApi?
  init(repository:CoreRepository) {
    let coordinator=ReminderCoordinator(core:repository,center:SystemReminderCenter())
    self.coordinator=coordinator
    super.init()
    UNUserNotificationCenter.current().delegate=self
    repository.reminderInvalidated={Task{await coordinator.reconcile()}}
    for name in [UIApplication.didBecomeActiveNotification,UIApplication.significantTimeChangeNotification,UIApplication.protectedDataDidBecomeAvailableNotification,NSNotification.Name.NSSystemTimeZoneDidChange] {
      observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main){_ in Task{await coordinator.reconcile()}})
    }
    Task {await coordinator.observe{[weak self] in Task{@MainActor in try? await self?.events?.changed()}}}
  }
  deinit {for observer in observers{NotificationCenter.default.removeObserver(observer)}}
  func attach(_ messenger:FlutterBinaryMessenger) {events=ReminderPlatformEventsApi(binaryMessenger:messenger)}
  private func mapped<T>(_ work:() async throws->T) async throws -> T {
    do{return try await work()}catch{throw MediaPlatformBridge.error(error)}
  }
  func readState() async throws -> String {try await mapped{try await coordinator.readState()}}
  func reconcile() async throws -> String {await coordinator.reconcile()}
  func requestPermission(context:String) async throws -> String {try await mapped{try await coordinator.requestPermission(context:context)}}
  func savePreferences(request:String) async throws -> String {try await mapped{try await coordinator.savePreferences(request)}}
  func resolvePreferences(request:String) async throws -> String {try await mapped{try await coordinator.resolvePreferences(request)}}
  func openSettings() async throws {
    guard let url=URL(string:UIApplication.openSettingsURLString),await UIApplication.shared.open(url) else{throw PigeonError(code:"NOT_AVAILABLE",message:nil,details:nil)}
  }
  func readTap() async throws -> String {try await mapped{try await coordinator.readTap()}}
  func acknowledgeTap(eventId:String) async throws {try await mapped{try await coordinator.acknowledgeTap(eventId)}}
  nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)->Void) {
    completionHandler(notification.request.identifier.hasPrefix("verdi.check.v1.") ? [.banner,.list,.sound]:[])
  }
  nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping()->Void) {
    guard response.actionIdentifier==UNNotificationDefaultActionIdentifier,response.notification.request.identifier.hasPrefix("verdi.check.v1.") else{completionHandler();return}
    let request=response.notification.request
    let bytes=try? JSONSerialization.data(withJSONObject:request.content.userInfo,options:[.sortedKeys])
    let payload=bytes.flatMap{String(data:$0,encoding:.utf8)} ?? "null"
    Task {
      // Attempt durable retention before completing; temporary disk failure keeps
      // a bounded in-memory retry. Losing that process can lose navigation only.
      try? await coordinator.retainTap(requestID:request.identifier,payload:payload)
      completionHandler()
    }
  }
}
