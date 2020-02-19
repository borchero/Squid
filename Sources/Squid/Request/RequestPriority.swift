//
//  RequestPriority.swift
//  Squid
//
//  Created by Oliver Borchert on 9/18/19.
//

import Foundation

/// The request priority can be used to govern how important a specific request is considered, i.e.
/// whether it must be scheduled right away or it can be scheduled some time in the background.
/// Currently, request priorities only influence the priority of the dispatch queue used to
/// schedule requests. However, in the future, request priorities might get integrated more deeply
/// into Squid and allow for more fine-grained control over the point in time when requests are
/// scheduled.
public enum RequestPriority {

    /// The utility priority indicates that the request may be scheduled at some time in the future.
    /// Scheduling is performed on some background thread.
    case utility

    /// The default priority indicates that requests is likely to be scheduled right away.
    case `default`

    /// The user initiated priority is the highest available priority and essentially guarantees
    /// that the request is scheduled right away.
    case userInitiated
}
