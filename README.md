# Squid

Squid is a declarative and reactive networking library for Swift. Developed for Swift 5, it aims to make use of the latest language features. The framework's ultimate goal is to enable easy networking that makes it easy to write well-maintainable code.

In its very core, it is built on top of Apple's [Combine](https://developer.apple.com/documentation/combine/) framework and uses Apple's builtin [URL loading system](https://developer.apple.com/documentation/foundation/url_loading_system) for networking.

## Features

At the moment, the most important features of Squid can be summarized as follows:

* Sending HTTP requests and receiving server responses.
* Retrying HTTP requests with a wide range of retriers.
* Automated requesting of new pages for paginated HTTP requests.
* Sending and receiving messages over WebSockets.
* Abstraction of API endpoints and security mechanisms for a set of requests.

## Installation

At the moment, Squid is only available via the [Swift Package Manager](https://swift.org/package-manager/).

In order to use it, simply go to `File > Swift Packages > Add Package Dependency...` in Xcode and add this repository.

## Documentation

Documentation is available [here](https://borchero.github.io/Squid) and provides both comprehensive documentation of the library's public interface as well as a series of guides teaching you how to use Squid to great effect. Expect more guides to be added shortly.

## License

Squid is licensed under the [MIT License](https://github.com/borchero/Squid/LICENSE).
