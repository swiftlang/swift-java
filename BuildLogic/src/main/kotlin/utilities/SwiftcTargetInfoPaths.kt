package utilities

import kotlinx.serialization.Serializable

@Serializable
internal data class SwiftcTargetInfoPaths(
    val runtimeLibraryPaths: List<String>,
)