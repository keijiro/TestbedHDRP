// Voxelizer effect geometry shader
// https://github.com/keijiro/TestbedHDRP

#include "Assets/CustomShader/Common/Shader/SimplexNoise3D.hlsl"

half2 _VoxelParams; // density, scale
half3 _AnimParams;  // stretch, fall distance, fluctuation
float4 _EffectorPlane;
float4 _PrevEffectorPlane;

PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position0, float3 position1, float3 position0_prev, float3 position1_prev,
    half3 normal0, half3 normal1, half param, half param_prev,
    half emission = 0, half random = 0, half2 baryCoord = 0.5
)
{
    return PackVertexData(
        source,
        lerp(position0, position1, param),
        lerp(position0_prev, position1_prev, param_prev),
        normalize(lerp(normal0, normal1, param)),
        half4(baryCoord, emission, random)
    );
}

// Calculates a cube position and scale.
void CubePosScale(
    float3 center, float size, float rand, float param,
    out float3 pos, out float3 scale
)
{
    const float VoxelScale = _VoxelParams.y;
    const float Stretch = _AnimParams.x;
    const float FallDist = _AnimParams.y;
    const float Fluctuation = _AnimParams.z;

    // Noise field
    float4 snoise = snoise_grad(float3(rand * 2378.34, param * 0.8, 0));

    // Stretch/move param
    float move = saturate(param * 4 - 3);
    move = move * move;

    // Cube position
    pos = center + snoise.xyz * size * Fluctuation;
    pos.y += move * move * lerp(0.25, 1, rand) * size * FallDist;

    // Cube scale anim
    scale = float2(1 - move, 1 + move * Stretch).xyx;
    scale *= size * VoxelScale * saturate(1 + snoise.w * 2);
}

[maxvertexcount(24)]
void VoxelizerGeometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<PackedVaryingsType> outStream
)
{
    const float VoxelDensity = _VoxelParams.x;

    // Input vertices
    AttributesMesh v0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh v1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh v2 = ConvertToAttributesMesh(input[2]);

    float3 p0 = v0.positionOS;
    float3 p1 = v1.positionOS;
    float3 p2 = v2.positionOS;

#if SHADERPASS == SHADERPASS_VELOCITY
    bool hasDeformation = unity_MotionVectorsParams.x > 0.0;
    float3 p0_prev = hasDeformation ? input[0].previousPositionOS : p0;
    float3 p1_prev = hasDeformation ? input[1].previousPositionOS : p1;
    float3 p2_prev = hasDeformation ? input[2].previousPositionOS : p2;
#else
    float3 p0_prev = p0;
    float3 p1_prev = p1;
    float3 p2_prev = p2;
#endif

#ifdef ATTRIBUTES_NEED_NORMAL
    float3 n0 = v0.normalOS;
    float3 n1 = v1.normalOS;
    float3 n2 = v2.normalOS;
#else
    float3 n0 = float3(1, 0, 0);
    float3 n1 = float3(1, 0, 0);
    float3 n2 = float3(1, 0, 0);
#endif

    float3 center = (p0 + p1 + p2) / 3;
    float size = distance(p0, center);

    float3 center_prev = (p0_prev + p1_prev + p2_prev) / 3;

    // Deformation parameter
    float3 center_ws = GetAbsolutePositionWS(TransformObjectToWorld(center));
    float param = 1 - dot(_EffectorPlane.xyz, center_ws) + _EffectorPlane.w;

    float3 center_ws_prev = GetAbsolutePositionWS(TransformObjectToWorld(center_prev));
    float param_prev = 1 - dot(_PrevEffectorPlane.xyz, center_ws_prev) + _PrevEffectorPlane.w;

    // Pass through the vertices if deformation hasn't been started yet.
    if (param < 0)
    {
        outStream.Append(VertexOutput(v0, p0, 0, p0_prev, 0, n0, 0, 0, 0));
        outStream.Append(VertexOutput(v1, p1, 0, p1_prev, 0, n1, 0, 0, 0));
        outStream.Append(VertexOutput(v2, p2, 0, p2_prev, 0, n2, 0, 0, 0));
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

        // Cube position and scale
        float3 pos, pos_prev, scale, scale_prev;
        CubePosScale(center_ws, size, rand1, param, pos, scale);
        CubePosScale(center_ws_prev, size, rand1, param_prev, pos_prev, scale_prev);

        // Secondary animation parameters
        float morph = smoothstep(0, 0.25, param);
        float morph_prev = smoothstep(0, 0.25, param_prev);

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

        float3 pc0_prev = pos_prev + float3(-1, -1, -1) * scale_prev;
        float3 pc1_prev = pos_prev + float3(+1, -1, -1) * scale_prev;
        float3 pc2_prev = pos_prev + float3(-1, +1, -1) * scale_prev;
        float3 pc3_prev = pos_prev + float3(+1, +1, -1) * scale_prev;
        float3 pc4_prev = pos_prev + float3(-1, -1, +1) * scale_prev;
        float3 pc5_prev = pos_prev + float3(+1, -1, +1) * scale_prev;
        float3 pc6_prev = pos_prev + float3(-1, +1, +1) * scale_prev;
        float3 pc7_prev = pos_prev + float3(+1, +1, +1) * scale_prev;

        // World space to object space conversion
        pc0 = TransformWorldToObject(GetCameraRelativePositionWS(pc0));
        pc1 = TransformWorldToObject(GetCameraRelativePositionWS(pc1));
        pc2 = TransformWorldToObject(GetCameraRelativePositionWS(pc2));
        pc3 = TransformWorldToObject(GetCameraRelativePositionWS(pc3));
        pc4 = TransformWorldToObject(GetCameraRelativePositionWS(pc4));
        pc5 = TransformWorldToObject(GetCameraRelativePositionWS(pc5));
        pc6 = TransformWorldToObject(GetCameraRelativePositionWS(pc6));
        pc7 = TransformWorldToObject(GetCameraRelativePositionWS(pc7));

        pc0_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc0_prev));
        pc1_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc1_prev));
        pc2_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc2_prev));
        pc3_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc3_prev));
        pc4_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc4_prev));
        pc5_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc5_prev));
        pc6_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc6_prev));
        pc7_prev = TransformWorldToObject(GetCameraRelativePositionWS(pc7_prev));

        // Vertex outputs
        float3 nc = TransformWorldToObjectDir(float3(-1, 0, 0));
        outStream.Append(VertexOutput(v0, p0, pc2, p0_prev, pc2_prev, n0, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc0, p2_prev, pc0_prev, n2, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v0, p0, pc6, p0_prev, pc6_prev, n0, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v2, p2, pc4, p2_prev, pc4_prev, n2, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = TransformWorldToObjectDir(float3(1, 0, 0));
        outStream.Append(VertexOutput(v2, p2, pc1, p2_prev, pc1_prev, n2, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v1, p1, pc3, p1_prev, pc3_prev, n1, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v2, p2, pc5, p2_prev, pc5_prev, n2, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v1, p1, pc7, p1_prev, pc7_prev, n1, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = TransformWorldToObjectDir(float3(0, -1, 0));
        outStream.Append(VertexOutput(v2, p2, pc0, p2_prev, pc0_prev, n2, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc1, p2_prev, pc1_prev, n2, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v2, p2, pc4, p2_prev, pc4_prev, n2, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v2, p2, pc5, p2_prev, pc5_prev, n2, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = TransformWorldToObjectDir(float3(0, 1, 0));
        outStream.Append(VertexOutput(v1, p1, pc3, p1_prev, pc3_prev, n1, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v0, p0, pc2, p0_prev, pc2_prev, n0, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v1, p1, pc7, p1_prev, pc7_prev, n1, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v0, p0, pc6, p0_prev, pc6_prev, n0, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = TransformWorldToObjectDir(float3(0, 0, -1));
        outStream.Append(VertexOutput(v2, p2, pc1, p2_prev, pc1_prev, n2, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc0, p2_prev, pc0_prev, n2, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v1, p1, pc3, p1_prev, pc3_prev, n1, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v0, p0, pc2, p0_prev, pc2_prev, n0, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();

        nc = TransformWorldToObjectDir(float3(0, 0, 1));
        outStream.Append(VertexOutput(v2, p2, pc4, p2_prev, pc4_prev, -n2, nc, morph, morph_prev, em, rand2, float2(0, 0)));
        outStream.Append(VertexOutput(v2, p2, pc5, p2_prev, pc5_prev, -n2, nc, morph, morph_prev, em, rand2, float2(1, 0)));
        outStream.Append(VertexOutput(v0, p0, pc6, p0_prev, pc6_prev, -n0, nc, morph, morph_prev, em, rand2, float2(0, 1)));
        outStream.Append(VertexOutput(v1, p1, pc7, p1_prev, pc7_prev, -n1, nc, morph, morph_prev, em, rand2, float2(1, 1)));
        outStream.RestartStrip();
    }
    else
    {
        // -- Triangle --
        half morph = smoothstep(0, 0.25, param);
        half morph_prev = smoothstep(0, 0.25, param_prev);
        half em = smoothstep(0, 0.15, param) * 2;
        outStream.Append(VertexOutput(v0, p0, center, p0_prev, center_prev, n0, n0, morph, morph_prev, em));
        outStream.Append(VertexOutput(v1, p1, center, p1_prev, center_prev, n1, n1, morph, morph_prev, em));
        outStream.Append(VertexOutput(v2, p2, center, p2_prev, center_prev, n2, n2, morph, morph_prev, em));
        outStream.RestartStrip();
    }
}
