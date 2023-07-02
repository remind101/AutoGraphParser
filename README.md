[![CircleCI](https://circleci.com/gh/remind101/AutoGraphParser.svg?style=svg)](https://app.circleci.com/pipelines/github/remind101/AutoGraphParser)
# AutoGraphParser
(Future) AutoGraph GQL Parser

Relies upon functional parser combinators https://github.com/pointfreeco/swift-parsing

- [x] GraphQL client Query parsing.
- [x] Introspection Schema JSON parsing.
- [ ] Full GraphQL schema parsing (future).

CI:
- [x] Linux Ubuntu
- [ ] Mac 

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
This project relies primarily on Swift Package Manager and NOT Xcode. It should always be runnable in the terminal.
