//
//  HttpMimeType.swift
//  Squid
//
//  Created by Oliver Borchert on 9/17/19.
//

import Foundation

/// This enum provides commonly used MIME types that are e.g. provided in HTTP requests'
/// 'Content-Type' header field.
public enum HttpMimeType: String {
    
    /// Mime type for JSON content.
    case json = "application/json"
    
    /// Mime type for PNG images.
    case png = "image/png"
    
    /// Mime type for JPEG images.
    case jpeg = "image/jpeg"
}
