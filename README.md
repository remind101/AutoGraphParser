# AutoGraphParser
(Future) AutoGraph GQL Parser

Relies upon functional parser combinators https://github.com/pointfreeco/swift-parsing

### Process

##### Building
```
swift build
```

##### Testing
```
swift test
```

##### Notes
This project relies primarily on Swift Package Manager and NOT Xcode. It should always be runnable in the terminal and in the future we should support VSCode as well as Xcode.

The repo is saved with a `.xcodeproj` via `swift package generate-xcodeproj`. Use this command to re-generate the Xcode project at any time.
