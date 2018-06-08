#include "SimplexNoise3D.hlsl"
#include "Utils.hlsl"

half _Extrusion;
float4 _Effector;
float _LocalTime;

float3 ConstructNormal(float3 v1, float3 v2, float3 v3)
{
    return normalize(cross(v2 - v1, v3 - v1));
}

PackedVaryingsMeshToPS VertexOutput(AttributesMesh v, float3 p, half3 n)
{
    v.positionOS = p;
#ifdef ATTRIBUTES_NEED_NORMAL
    v.normalOS = n;
#endif
    return PackVaryingsMeshToPS(VertMesh(v));
}

PackedVaryingsMeshToPS CubeVertex(
    AttributesMesh src,
    float3 pos, half3 normal0, half3 normal1, half3 bary0, half2 bary1,
    half morph, half emission
)
{
    half3 normal = normalize(lerp(normal0, normal1, morph));
    half3 bary = lerp(bary0, half3(bary1, 0.5), morph);
    return VertexOutput(src, pos, normal);
}

PackedVaryingsMeshToPS TriangleVertex(
    AttributesMesh src,
    float3 pos, half3 normal, half3 bary, half emission
)
{
    return VertexOutput(src, pos, normal);
}

[maxvertexcount(24)]
void Geom(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<PackedVaryingsMeshToPS> outStream
)
{
    // Input vertices
    AttributesMesh v0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh v1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh v2 = ConvertToAttributesMesh(input[2]);

    float3 p0 = v0.positionOS;
    float3 p1 = v1.positionOS;
    float3 p2 = v2.positionOS;

#ifdef ATTRIBUTES_NEED_NORMAL
    float3 n0 = v0.normalOS;
    float3 n1 = v1.normalOS;
    float3 n2 = v2.normalOS;
#else
    float3 n0 = 0;
    float3 n1 = 0;
    float3 n2 = 0;
#endif

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = 1 - dot(_Effector.xyz, TransformObjectToWorld(center)) + _Effector.w;

    // Pass through the vertices if deformation hasn't been started yet.
    if (param < 0)
    {
        outStream.Append(VertexOutput(v0, p0, n0));
        outStream.Append(VertexOutput(v1, p1, n1));
        outStream.Append(VertexOutput(v2, p2, n2));
        outStream.RestartStrip();
        return;
    }

    // Draw nothing at the end of deformation.
    if (param >= 1) return;

    // Choose cube/triangle randomly.
    uint seed = pid * 877;
    if (Hash(seed) < 0.05)
    {
        // -- Cube --

        // Random number, noise field
        float random = Hash(seed + 1);
        float4 snoise = snoise_grad(float3(random * 2378.34, param * 0.8, 0));

        // Stretch/move param
        float move = saturate(param * 4 - 3);
        move = move * move;

        // Cube position
        float3 pos = center + snoise.xyz * 0.02;
        pos.y += move * random;

        // Cube scale anim
        float3 scale = float2(1 - move, 1 + move * 5).xyx;
        scale *= 0.05 * saturate(1 + snoise.w * 2);

        // Edge color (emission power)
        float edge = saturate(param * 5);

        // Cube points calculation
        float morph = smoothstep(0, 0.25, param);
        float3 c_p0 = lerp(p2, pos + float3(-1, -1, -1) * scale, morph);
        float3 c_p1 = lerp(p2, pos + float3(+1, -1, -1) * scale, morph);
        float3 c_p2 = lerp(p0, pos + float3(-1, +1, -1) * scale, morph);
        float3 c_p3 = lerp(p1, pos + float3(+1, +1, -1) * scale, morph);
        float3 c_p4 = lerp(p2, pos + float3(-1, -1, +1) * scale, morph);
        float3 c_p5 = lerp(p2, pos + float3(+1, -1, +1) * scale, morph);
        float3 c_p6 = lerp(p0, pos + float3(-1, +1, +1) * scale, morph);
        float3 c_p7 = lerp(p1, pos + float3(+1, +1, +1) * scale, morph);

        // Vertex outputs
        float3 c_n = float3(-1, 0, 0);
        outStream.Append(CubeVertex(v0, c_p2, n0, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p0, n2, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v0, c_p6, n0, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v2, c_p4, n2, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(1, 0, 0);
        outStream.Append(CubeVertex(v2, c_p1, n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v1, c_p3, n1, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p5, n2, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v1, c_p7, n1, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, -1, 0);
        outStream.Append(CubeVertex(v2, c_p0, n2, c_n, float3(1, 0, 0), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p1, n2, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p4, n2, c_n, float3(1, 0, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v2, c_p5, n2, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 1, 0);
        outStream.Append(CubeVertex(v1, c_p3, n1, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v0, c_p2, n0, c_n, float3(1, 0, 0), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v1, c_p7, n1, c_n, float3(0, 0, 1), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v0, c_p6, n0, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, -1);
        outStream.Append(CubeVertex(v2, c_p1, n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p0, n2, c_n, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v1, c_p3, n1, c_n, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v0, c_p2, n0, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();

        c_n = float3(0, 0, 1);
        outStream.Append(CubeVertex(v2, c_p4, -n2, c_n, float3(0, 0, 1), float2(0, 0), morph, edge));
        outStream.Append(CubeVertex(v2, c_p5, -n2, c_n, float3(0, 0, 1), float2(1, 0), morph, edge));
        outStream.Append(CubeVertex(v0, c_p6, -n0, c_n, float3(0, 1, 0), float2(0, 1), morph, edge));
        outStream.Append(CubeVertex(v1, c_p7, -n1, c_n, float3(1, 0, 0), float2(1, 1), morph, edge));
        outStream.RestartStrip();
    }
    else
    {
        // -- Triangle --

        float ss_param = smoothstep(0, 1, param);

        // Random motion
        float3 move = RandomInsideSphere(seed + 1) * ss_param * 0.5;

        // Random rotation
        float3 rot_angles = (RandomInsideCube(seed + 4) - 0.5) * 100;
        float3x3 rot_m = Euler3x3(rot_angles * ss_param);

        // Simple shrink
        float scale = 1 - ss_param;

        // Apply the animation.
        float3 t_p0 = mul(rot_m, p0 - center) * scale + center + move;
        float3 t_p1 = mul(rot_m, p1 - center) * scale + center + move;
        float3 t_p2 = mul(rot_m, p2 - center) * scale + center + move;
        float3 normal = normalize(cross(t_p1 - t_p0, t_p2 - t_p0));

        // Edge color (emission power) animation
        float edge = smoothstep(0, 0.1, param); // ease-in
        edge *= 1 + 20 * smoothstep(0, 0.1, 0.1 - param); // peak -> release

        // Vertex outputs (front face)
        outStream.Append(TriangleVertex(v0, t_p0, normal, float3(1, 0, 0), edge));
        outStream.Append(TriangleVertex(v1, t_p1, normal, float3(0, 1, 0), edge));
        outStream.Append(TriangleVertex(v2, t_p2, normal, float3(0, 0, 1), edge));
        outStream.RestartStrip();

        // Vertex outputs (back face)
        outStream.Append(TriangleVertex(v0, t_p0, -normal, float3(1, 0, 0), edge));
        outStream.Append(TriangleVertex(v2, t_p2, -normal, float3(0, 0, 1), edge));
        outStream.Append(TriangleVertex(v1, t_p1, -normal, float3(0, 1, 0), edge));
        outStream.RestartStrip();
    }
}
