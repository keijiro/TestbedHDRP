// Common vertex utilities for custom lit shaders
// https://github.com/keijiro/TestbedHDRP

// Attributes struct has to be redefined to change the type of positionOS to
// float4; It's originally defined as float3, and it causes "Not all elements
// of SV_Position were written" error when used in a geometry shader.

// Also previousPositionOS is added to support the motion vectors pass.

struct Attributes
{
    float4 positionOS   : POSITION;
#ifdef ATTRIBUTES_NEED_NORMAL
    float3 normalOS     : NORMAL;
#endif
#ifdef ATTRIBUTES_NEED_TANGENT
    float4 tangentOS    : TANGENT; // Store sign in w
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD0
    float2 uv0          : TEXCOORD0;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD1
    float2 uv1          : TEXCOORD1;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD2
    float2 uv2          : TEXCOORD2;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD3
    float2 uv3          : TEXCOORD3;
#endif
#if SHADERPASS == SHADERPASS_MOTION_VECTORS
    float3 previousPositionOS : TEXCOORD4; // Contain previous transform position (in case of skinning for example)
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    float4 color        : COLOR;
#endif

UNITY_VERTEX_INPUT_INSTANCE_ID
};

AttributesMesh ConvertToAttributesMesh(Attributes input)
{
    AttributesMesh am;
    am.positionOS = input.positionOS.xyz;
#ifdef ATTRIBUTES_NEED_NORMAL
    am.normalOS = input.normalOS;
#endif
#ifdef ATTRIBUTES_NEED_TANGENT
    am.tangentOS = input.tangentOS;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD0
    am.uv0 = input.uv0;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD1
    am.uv1 = input.uv1;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD2
    am.uv2 = input.uv2;
#endif
#ifdef ATTRIBUTES_NEED_TEXCOORD3
    am.uv3 = input.uv3;
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    am.color = input.color;
#endif
    UNITY_TRANSFER_INSTANCE_ID(input, am);
    return am;
}

// Passthrough vertex shader
// We do all vertex calculations in the geometry shader.
void VertexThru(inout Attributes input) {}

// Vertex data pack function
// Re-pack the vertex data and apply the original vertex function.
PackedVaryingsType PackVertexData(
    AttributesMesh source,
    float3 position, float3 position_prev, float3 normal, float4 color
)
{
    source.positionOS = position;
#if defined(VARYINGS_NEED_TEXCOORD1) || defined(VARYINGS_DS_NEED_TEXCOORD1)
    // FIXME: I'm not sure why but the shader compiler emits an "unexpected
    // LEFT_BRACKET" error on Vulkan. Strangely, it disappears by touching UV1
    // before calling VertMesh.
    source.uv1 = source.uv1 + 1e-12;
#endif
#ifdef ATTRIBUTES_NEED_NORMAL
    source.normalOS = normal;
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    source.color = color;
#endif
#if SHADERPASS == SHADERPASS_MOTION_VECTORS
    AttributesPass attrib;
    attrib.previousPositionOS = position_prev;
    return Vert(source, attrib);
#else
    return Vert(source);
#endif
}
