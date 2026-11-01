import Flutter
import UIKit

/// No repository, log, receipt, photo or network dependency.
@MainActor
final class HelpPlatformBridge: HelpPlatformHostApi {
  func getFeedbackMetadata() async throws -> String {
    func version(_ value:String?,limit:Int)->Any {
      guard let value,!value.isEmpty,value.count<=limit,!value.unicodeScalars.contains(where:{$0.value==0}) else{return NSNull()}
      return value
    }
    let result:[String:Any]=[
      "draftId":UUID().uuidString.lowercased(),"destination":NSNull(),
      "appVersion":version(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,limit:80),
      "build":version(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String,limit:40),
      "osVersion":version(UIDevice.current.systemVersion,limit:40)
    ]
    return String(decoding:try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]),as:UTF8.self)
  }
}
