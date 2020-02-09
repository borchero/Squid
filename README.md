# Squid

![Cocoapods](https://img.shields.io/cocoapods/v/Squid)
![Build](https://github.com/borchero/Squid/workflows/Build/badge.svg?branch=master)
![CocoaPods](https://github.com/borchero/Squid/workflows/CocoaPods/badge.svg?branch=master)
![Documentation](https://github.com/borchero/Squid/workflows/Documentation/badge.svg?branch=master)

Squid is a declarative and reactive networking library for Swift. Developed for Swift 5, it aims to make use of the latest language features. The framework's ultimate goal is to enable easy networking that makes it easy to write well-maintainable code.

In its very core, it is built on top of Apple's [Combine](https://developer.apple.com/documentation/combine/) framework and uses Apple's builtin [URL loading system](https://developer.apple.com/documentation/foundation/url_loading_system) for networking.

## Features

At the moment, the most important features of Squid can be summarized as follows:

* Sending HTTP requests and receiving server responses.
* Retrying HTTP requests with a wide range of retriers.
* Automated requesting of new pages for paginated HTTP requests.
* Sending and receiving messages over WebSockets.
* Abstraction of API endpoints and security mechanisms for a set of requests.

## Quickstart

When first using Squid, you might want to try out requests against a [Test API](https://jsonplaceholder.typicode.com/).

To perform a sample request at this API, we first define an API to manage its endpoint:

```swift
struct MyApi: HttpService {

    var apiUrl: UrlConvertible {
        "jsonplaceholder.typicode.com"
    }
}
```

Afterwards, we can define the request itself:

```swift
struct Todo: Decodable {

    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

struct TodoRequest: JsonRequest {

    typealias Result = Todo
    
    let id: Int
    
    var routes: HttpRoute {
        ["todos", id]
    }
}
```

And schedule the request as follows:

```swift
let api = MyApi()
let request = TodoRequest(id: 1)

// The following request will be scheduled to `https://jsonplaceholder.typicode.com/todos/1`
request.schedule(with: api).ignoreError().sink { todo in 
    // work with `todo` here
}
```

## Installation

Squid is available via the [Swift Package Manager](https://swift.org/package-manager/) as well as [CocoaPods](https://cocoapods.org).

### Swift Package Manager

Using the Swift Package Manager is the simplest option to use Squid. In Xcode, simply go to `File > Swift Packages > Add Package Dependency...` and add this repository.

If you are developing a Swift package, adding Squid as a dependency is as easy as adding it to the dependencies of your `Package.swift` like so:

```swift
dependencies: [
    .package(url: "https://github.com/borchero/Squid.git")
]
```

### CocoaPods

If you are still using CocoaPods or are required to use it due to other dependencies that are not yet available for the Swift Package Manager, you can include the following line in your Podfile to use the latest version of Squid:

```ruby
pod 'Squid'
```

### Specifying Versions

If you want to use a particular version, consult the `Releases` page for the exact latest available version. Currently, the latest version is `1.1.x`.

## Documentation

Documentation is available [here](https://borchero.github.io/Squid/) and provides both comprehensive documentation of the library's public interface as well as a series of guides teaching you how to use Squid to great effect. Expect more guides to be added shortly.

## License

Squid is licensed under the [MIT License](https://github.com/borchero/Squid/blob/master/LICENSE).
