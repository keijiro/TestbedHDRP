#include "HDRP/ShaderVariables.hlsl"
#include "HDRP/Material/Material.hlsl"

#if SHADERPASS == SHADERPASS_GBUFFER
#include "HDRP/Material/Lit/ShaderPass/LitSharePass.hlsl"
#elif SHADERPASS == SHADERPASS_SHADOWS
#include "HDRP/Material/Lit/ShaderPass/LitDepthPass.hlsl"
#endif

#include "HDRP/Material/Lit/LitData.hlsl"

#if SHADERPASS == SHADERPASS_GBUFFER
#include "HDRP/ShaderPass/ShaderPassGBuffer.hlsl"
#elif SHADERPASS == SHADERPASS_SHADOWS
#include "HDRP/ShaderPass/ShaderPassDepthOnly.hlsl"
#endif

#include "SimplexNoise3D.hlsl"
#include "Utils.hlsl"

// Empty vertex shader
// We do all the vertex calculations in the geometry shader.
void VertNull(inout Attributes input) {}

float3 ConstructNormal(float3 v1, float3 v2, float3 v3)
{
    return normalize(cross(v2 - v1, v3 - v1));
}

PackedVaryingsMeshToPS OutputVertex(AttributesMesh src, float3 p, half3 n)
{
    src.positionOS = p;
#ifdef ATTRIBUTES_NEED_NORMAL
    src.normalOS = n;
#endif
    return PackVaryingsMeshToPS(VertMesh(src));
}

//
// Geometry shader
//
[maxvertexcount(15)]
void Geom(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<PackedVaryingsMeshToPS> outStream
)
{
    AttributesMesh i0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh i1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh i2 = ConvertToAttributesMesh(input[2]);

    float3 p0 = i0.positionOS;
    float3 p1 = i1.positionOS;
    float3 p2 = i2.positionOS;

    // Extrusion amount
    float ext = saturate(0.4 - cos(_Time.y) * 0.41);
    ext *= 0.3 + 0.1 * sin(frac(pid * 2.374843) * PI * 2 + _Time.y * 8.76);

    // Extrusion points
    float3 offs = ConstructNormal(p0, p1, p2) * ext;
    float3 p3 = p0 + offs;
    float3 p4 = p1 + offs;
    float3 p5 = p2 + offs;

    // Cap triangle
    float3 n = ConstructNormal(p3, p4, p5);
    float np = saturate(ext * 10);
#ifdef ATTRIBUTES_NEED_NORMAL
    outStream.Append(OutputVertex(i0, p3, lerp(i0.normalOS, n, np)));
    outStream.Append(OutputVertex(i1, p4, lerp(i1.normalOS, n, np)));
    outStream.Append(OutputVertex(i2, p5, lerp(i2.normalOS, n, np)));
#else
    outStream.Append(OutputVertex(i0, p3, n));
    outStream.Append(OutputVertex(i1, p4, n));
    outStream.Append(OutputVertex(i2, p5, n));
#endif
    outStream.RestartStrip();

    // Side faces
    float4 t = float4(normalize(p3 - p0), 1);
    n = ConstructNormal(p3, p0, p4);
    outStream.Append(OutputVertex(i0, p3, n));
    outStream.Append(OutputVertex(i0, p0, n));
    outStream.Append(OutputVertex(i1, p4, n));
    outStream.Append(OutputVertex(i1, p1, n));
    outStream.RestartStrip();

    n = ConstructNormal(p4, p1, p5);
    outStream.Append(OutputVertex(i1, p4, n));
    outStream.Append(OutputVertex(i1, p1, n));
    outStream.Append(OutputVertex(i2, p5, n));
    outStream.Append(OutputVertex(i2, p2, n));
    outStream.RestartStrip();

    n = ConstructNormal(p5, p2, p3);
    outStream.Append(OutputVertex(i2, p5, n));
    outStream.Append(OutputVertex(i2, p2, n));
    outStream.Append(OutputVertex(i0, p3, n));
    outStream.Append(OutputVertex(i0, p0, n));
    outStream.RestartStrip();
}
