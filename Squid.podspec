#
#  Squid.podspec
#  Squid
#
#  Created by Oliver Borchert on 10/14/19.
#  Copyright (c) 2019 Oliver Borchert. All rights reserved.
#

Pod::Spec.new do |s|

    s.name = 'Squid'
    s.version = '1.1.2'
    s.license = 'MIT'
    s.summary = 'Declarative and Reactive Networking in Swift.'

    s.homepage = 'https://borchero.github.io/Squid/'
    s.authors = { 'Oliver Borchert' => 'borchero@in.tum.de' }
    s.source = {
        :git => 'https://github.com/borchero/Squid.git',
        :tag => s.version
    }
    s.documentation_url = 'https://borchero.github.io/Squid/'

    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.15'
    s.tvos.deployment_target = '13.0'
    s.watchos.deployment_target = '6.0'

    s.swift_versions = ['5.0', '5.1']

    s.source_files = 'Sources/Squid/**/*.swift'

end
