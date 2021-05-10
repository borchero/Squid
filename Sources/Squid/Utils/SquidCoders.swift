import Foundation

public class SquidCoders {
    private init() {}
    
    public static let shared = SquidCoders()
    public var decoder = JSONDecoder()
    public var encoder = JSONEncoder()
}
