#include "SimplexNoise3D.hlsl"
#include "Utils.hlsl"

half _Extrusion;
float4 _Effector;
float _LocalTime;

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
    float3 pc = TransformObjectToWorld((p0 + p1 + p2) / 3);
    float ext = saturate(dot(pc, _Effector.xyz) - _Effector.w);
    ext *= max(0, _Extrusion * sin(frac(pid * 2.374843) * PI * 2 + _LocalTime * 8.76));

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
