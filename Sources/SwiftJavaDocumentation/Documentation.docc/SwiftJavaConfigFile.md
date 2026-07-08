# swift-java.config

Many of the tools–as well as SwiftPM plugin's–behaviors can be configured using the `swift-java.config` file.

### The swift-java.config file

You can refer to the `SwiftJavaConfigurationShared/Configuration` struct to learn about the supported options.

Configuration from the config files may be overriden or augmented by explicit command line parameters,
please refer to the options documentation for details on their behavior.

### Comments

The configuration is a JSON 5 file, which among other things allows `//` and `/* */` comments, so feel free to add line comments explaining rationale for some of the settings in youf configuration.

## Supported configuration options

<!-- SWIFT_JAVA_CONFIG_DOCS:START -->

<!-- SWIFT_JAVA_CONFIG_DOCS:END -->