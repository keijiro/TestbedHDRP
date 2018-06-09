#include "SimplexNoise3D.hlsl"

// Random vector generators

float3 RandomOnSphere(uint seed)
{
    return SampleSphereUniform(Hash(seed), Hash(seed + 1));
}

float3 RandomInsideSphere(uint seed)
{
    return RandomOnSphere(seed) * sqrt(Hash(seed + 2));
}

float3 RandomInsideCube(uint seed)
{
    return float3(Hash(seed), Hash(seed + 1), Hash(seed + 2));
}

// Euler angles rotation matrix
float3x3 Euler3x3(float3 v)
{
    float sx, cx;
    float sy, cy;
    float sz, cz;

    sincos(v.x, sx, cx);
    sincos(v.y, sy, cy);
    sincos(v.z, sz, cz);

    float3 row1 = float3(sx*sy*sz + cy*cz, sx*sy*cz - cy*sz, cx*sy);
    float3 row3 = float3(sx*cy*sz - sy*cz, sx*cy*cz + sy*sz, cx*cy);
    float3 row2 = float3(cx*sz, cx*cz, -sx);

    return float3x3(row1, row2, row3);
}

// We have to redefine the attributes struct to change the type of positionOS
// to float4; It's originally defined as float3 so that it emits the "Not all
// elements of SV_Position were written" error when used in geometry shaders.

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

// Thru vertex shader
// We do all the vertex calculations in the geometry shader.
void VertexThru(inout Attributes input) {}
