# AutoGraphParser
[![CircleCI](https://circleci.com/gh/remind101/AutoGraphParser.svg?style=shield)](https://app.circleci.com/pipelines/github/remind101/AutoGraphParser)

The Swiftest way to GQL Parsing

Relies upon functional parser combinators https://github.com/pointfreeco/swift-parsing.

Conforming to 2021 [spec](https://spec.graphql.org/October2021/).

- [x] GraphQL client Query parsing.
- [x] Introspection Schema JSON parsing.
- [ ] Full GraphQL schema parsing (future).

CI:
- [x] Linux Ubuntu
- [x] Mac 

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
