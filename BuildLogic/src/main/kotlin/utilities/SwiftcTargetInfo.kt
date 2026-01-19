package utilities

import kotlinx.serialization.Serializable

@Serializable
internal data class SwiftcTargetInfo(
    val paths: SwiftcTargetInfoPaths,
)