half2 _VoxelParams; // density, scale
half3 _AnimParams;  // stretch, fall distance, fluctuation
float4 _EffectorPlane;
float _LocalTime;

PackedVaryingsMeshToPS VertexOutput(
    AttributesMesh source,
    float3 position, half3 normal,
    half emission = 0, half random = 0, half2 baryCoord = 0.5
)
{
    source.positionOS = position;
#ifdef ATTRIBUTES_NEED_NORMAL
    source.normalOS = normal;
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    source.color = half4(baryCoord, emission, random);
#endif
    return PackVaryingsMeshToPS(VertMesh(source));
}

PackedVaryingsMeshToPS CubeVertexOutput(
    AttributesMesh source,
    float3 position, half3 normal0, half3 normal1, half normalParam,
    half emission, half random, half2 baryCoord
)
{
    half3 normal = normalize(lerp(normal0, normal1, normalParam));
    return VertexOutput(source, position, normal, emission, random, baryCoord);
}

[maxvertexcount(24)]
void VoxelizerGeometry(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<PackedVaryingsMeshToPS> outStream
)
{
    // Parameter extraction
    const float VoxelDensity = _VoxelParams.x;
    const float VoxelScale = _VoxelParams.y;
    const float Stretch = _AnimParams.x;
    const float FallDist = _AnimParams.y;
    const float Fluctuation = _AnimParams.z;

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
    float size = distance(p0, center);

    // Deformation parameter
    float param = dot(_EffectorPlane.xyz, TransformObjectToWorld(center));
    param = 1 - param + _EffectorPlane.w;

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
    if (Hash(seed) < VoxelDensity)
    {
        // -- Cube --

        // Random number, noise field
        float random = Hash(seed + 1);
        float4 snoise = snoise_grad(float3(random * 2378.34, param * 0.8, 0));

        // Stretch/move param
        float move = saturate(param * 4 - 3);
        move = move * move;

        // Cube position
        float3 pos = center + snoise.xyz * size * Fluctuation;
        pos.y += move * move * lerp(0.25, 1, random) * size * FallDist;

        // Cube scale anim
        float3 scale = float2(1 - move, 1 + move * Stretch).xyx;
        scale *= size * VoxelScale * saturate(1 + snoise.w * 2);

        // Edge color (emission power)
        float edge = saturate(param * 5);
        float random2 = Hash(seed + 20000);

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
        outStream.Append(CubeVertexOutput(v0, c_p2, n0, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p0, n2, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v0, c_p6, n0, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v2, c_p4, n2, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();

        c_n = float3(1, 0, 0);
        outStream.Append(CubeVertexOutput(v2, c_p1, n2, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v1, c_p3, n1, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p5, n2, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v1, c_p7, n1, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();

        c_n = float3(0, -1, 0);
        outStream.Append(CubeVertexOutput(v2, c_p0, n2, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p1, n2, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p4, n2, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v2, c_p5, n2, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();

        c_n = float3(0, 1, 0);
        outStream.Append(CubeVertexOutput(v1, c_p3, n1, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v0, c_p2, n0, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v1, c_p7, n1, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v0, c_p6, n0, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();

        c_n = float3(0, 0, -1);
        outStream.Append(CubeVertexOutput(v2, c_p1, n2, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p0, n2, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v1, c_p3, n1, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v0, c_p2, n0, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();

        c_n = float3(0, 0, 1);
        outStream.Append(CubeVertexOutput(v2, c_p4, -n2, c_n, morph, edge, random2, float2(0, 0)));
        outStream.Append(CubeVertexOutput(v2, c_p5, -n2, c_n, morph, edge, random2, float2(1, 0)));
        outStream.Append(CubeVertexOutput(v0, c_p6, -n0, c_n, morph, edge, random2, float2(0, 1)));
        outStream.Append(CubeVertexOutput(v1, c_p7, -n1, c_n, morph, edge, random2, float2(1, 1)));
        outStream.RestartStrip();
    }
    else
    {
        // -- Triangle --
        half param2 = smoothstep(0.2, 0.3, param);
        outStream.Append(VertexOutput(v0, lerp(p0, center, param2), n0, param2));
        outStream.Append(VertexOutput(v1, lerp(p1, center, param2), n1, param2));
        outStream.Append(VertexOutput(v2, lerp(p2, center, param2), n2, param2));
        outStream.RestartStrip();
    }
}
