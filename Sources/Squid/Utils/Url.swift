//
//  Url.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// Any entity implementing this protocol declares that it is able to possibly represent itself as
/// a url. The conversion to this url may fail, however.
public protocol UrlConvertible {

    /// Returns `self` as url if possible or `nil` otherwise.
    var url: URL? { get }
}

extension URL: UrlConvertible {

    /// Simply returns `self`, `nil` is never returned.
    public var url: URL? {
        return self
    }
}

extension String: UrlConvertible {

    /// Returns `self` by converting into a url. All characters are encoded to be allowed in host
    /// as well as path strings. If conversion is not possible for some reason, `nil` is returned.
    public var url: URL? {
        let allowed = CharacterSet.urlHostAllowed.union(.urlPathAllowed)
        let escaped = self.addingPercentEncoding(withAllowedCharacters: allowed)
        guard let str = escaped else {
            return nil
        }
        return URL(string: str)
    }
}
