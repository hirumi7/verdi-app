/// Photos can successfully finish an empty change block. A completed transaction
/// alone is not evidence that an asset creation request was constructed.
public enum CardSaveResult: Equatable {
    case saved, failed, unknown
    public static func resolve(requestCreated:Bool,completed:Bool,errorReported:Bool)->Self {
        guard requestCreated else{return .failed}
        if completed && !errorReported {return .saved}
        return errorReported ? .failed:.unknown
    }
    public var code:String? {switch self {case .saved:return nil;case .failed:return "PHOTO_SAVE_FAILED";case .unknown:return "PHOTO_SAVE_UNKNOWN"}}
}
