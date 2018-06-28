half2 _VoxelParams; // density, scale
half3 _AnimParams;  // stretch, fall distance, fluctuation
float4 _EffectorPlane;
float _LocalTime;

PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position0, float3 position1, half3 normal0, half3 normal1, half param,
    half emission = 0, half random = 0, half2 baryCoord = 0.5
)
{
    source.positionOS = lerp(position0, position1, param);
#ifdef ATTRIBUTES_NEED_NORMAL
    source.normalOS = normalize(lerp(normal0, normal1, param));
#endif
#ifdef ATTRIBUTES_NEED_COLOR
    source.color = half4(baryCoord, emission, random);
#endif
    return Vert(source);
}

[maxvertexcount(24)]
void VoxelizerGeometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<PackedVaryingsType> outStream
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
        outStream.Append(VertexOutput(v0, p0, 0, n0, 0, 0));
        outStream.Append(VertexOutput(v1, p1, 0, n1, 0, 0));
        outStream.Append(VertexOutput(v2, p2, 0, n2, 0, 0));
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

        // Random numbers
        float rand1 = Hash(seed + 1);
        float rand2 = Hash(seed + 5);

        // Noise field
        float4 snoise = snoise_grad(float3(rand1 * 2378.34, param * 0.8, 0));

        // Stretch/move param
        float move = saturate(param * 4 - 3);
        move = move * move;

        // Cube position
        float3 pos = center + snoise.xyz * size * Fluctuation;
        pos.y += move * move * lerp(0.25, 1, rand1) * size * FallDist;

        // Cube scale anim
        float3 scale = float2(1 - move, 1 + move * Stretch).xyx;
        scale *= size * VoxelScale * saturate(1 + snoise.w * 2);

        // Secondary animation parameters
        float morph = smoothstep(0, 0.25, param);
        float em = smoothstep(0, 0.15, param) * 2; // initial emission
        em = min(em, 1 + smoothstep(0.8, 0.9, 1 - param));
        em += smoothstep(0.75, 1, param); // emission while falling

        // Cube points calculation
        float3 pc0 = pos + float3(-1, -1, -1) * scale;
        float3 pc1 = pos + float3(+1, -1, -1) * scale;
        float3 pc2 = pos + float3(-1, +1, -1) * scale;
        float3 pc3 = pos + float3(+1, +1, -1) * scale;
        float3 pc4 = pos + float3(-1, -1, +1) * scale;
        float3 pc5 = pos + float3(+1, -1, +1) * scale;
        float3 pc6 = pos + float3(-1, +1, +1) * scale;
        float3 pc7 = pos + float3(+1, +1, +1) * scale;

        // Vertex outputs
        float3 nc = float3(-1, 0, 0);
        outStream.Append(VertexOutput(v0, p0, pc2, n0, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc0, n2, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v0, p0, pc6, n0, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v2, p2, pc4, n2, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = float3(1, 0, 0);
        outStream.Append(VertexOutput(v2, p2, pc1, n2, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v1, p1, pc3, n1, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v2, p2, pc5, n2, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v1, p1, pc7, n1, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = float3(0, -1, 0);
        outStream.Append(VertexOutput(v2, p2, pc0, n2, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc1, n2, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v2, p2, pc4, n2, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v2, p2, pc5, n2, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = float3(0, 1, 0);
        outStream.Append(VertexOutput(v1, p1, pc3, n1, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v0, p0, pc2, n0, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v1, p1, pc7, n1, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v0, p0, pc6, n0, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = float3(0, 0, -1);
        outStream.Append(VertexOutput(v2, p2, pc1, n2, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc0, n2, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v1, p1, pc3, n1, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v0, p0, pc2, n0, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = float3(0, 0, 1);
        outStream.Append(VertexOutput(v2, p2, pc4, -n2, nc, morph, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc5, -n2, nc, morph, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v0, p0, pc6, -n0, nc, morph, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v1, p1, pc7, -n1, nc, morph, em, rand2, float2(1, 1)));
        outStream.RestartStrip();
    }
    else
    {
        // -- Triangle --
        half morph = smoothstep(0, 0.25, param);
        half em = smoothstep(0, 0.15, param) * 2;
        outStream.Append(VertexOutput(v0, p0, center, n0, n0, morph, em));
        outStream.Append(VertexOutput(v1, p1, center, n1, n1, morph, em));
        outStream.Append(VertexOutput(v2, p2, center, n2, n2, morph, em));
        outStream.RestartStrip();
    }
}
