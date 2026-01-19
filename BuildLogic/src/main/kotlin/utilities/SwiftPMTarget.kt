package utilities

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
internal data class SwiftPMTarget(
    @SerialName("product_dependencies")
    val productDependencies: List<String> = emptyList(),
    @SerialName("product_memberships")
    val productMemberships: List<String> = emptyList(),
)