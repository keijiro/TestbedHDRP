// Spiralizer effect geometry shader
// https://github.com/keijiro/TestbedHDRP

#define SEGMENT_COUNT 16

float3 _BaseParams; // density, size, highlight probability
float2 _AnimParams; // inflation, angle
float2 _TimeParams; // current, previous
float4x4 _EffSpace;
float4 _EffPlaneC;
float4 _EffPlaneP;

// Calculate an animation parameter from an object space position.
float AnimationParameter(float4 plane, float3 positionOS, uint primitiveID)
{
    float3 positionWS = GetAbsolutePositionWS(TransformObjectToWorld(positionOS));
    float param = dot(plane.xyz, positionWS) - plane.w;
    float random = lerp(1, 1.5, Hash(primitiveID * 761)); // 50% distribution
    return 1 - saturate(param * random);
}

// Vertex output from geometry
PackedVaryingsType VertexOutput(
    AttributesMesh source,
    float3 position, float3 position_prev, half3 normal,
    half emission = 0, half random = 0, half2 qcoord = -1
)
{
    half4 color = half4(qcoord, emission, random);
    return PackVertexData(source, position, position_prev, normal, color);
}

struct SpiralPoint
{
    float3 p0, p1, n;
};

float3 CylindricalCoord(float3 p)
{
    p = mul((float3x3)_EffSpace, p);
    return float3(length(p.xz), atan2(p.x, p.z), p.y); // dist, azimuth, height
}

SpiralPoint GetSpiralPoint(float3 cyl_pos, float seg_param, float anim_param)
{
    const float Width = _BaseParams.y;
    const float TotalAngle = _AnimParams.y;

    const half3 Ax = _EffSpace[0].xyz;
    const half3 Ay = _EffSpace[1].xyz;
    const half3 Az = _EffSpace[2].xyz;

    float angle_param = smoothstep(0.5 * seg_param, 0.5 + 0.5 * seg_param, anim_param);
    float angle = cyl_pos.y + TotalAngle * angle_param;

    float3 normal = Ax * sin(angle) + Az * cos(angle);

    float width_param = smoothstep(0, 0.5, min(seg_param, 1 - seg_param));
    width_param *= smoothstep(0, 0.1, min(angle_param, 1 - angle_param));
    float width = Width * width_param;

    SpiralPoint pt;
    pt.p0 = normal * cyl_pos.x + Ay * (cyl_pos.z - width);
    pt.p1 = normal * cyl_pos.x + Ay * (cyl_pos.z + width);
    pt.n = normal;
    return pt;
}

// Geometry shader function body
[maxvertexcount(SEGMENT_COUNT * 2)]
void SpiralizerGeometry(
    uint pid : SV_PrimitiveID,
    triangle Attributes input[3],
    inout TriangleStream<PackedVaryingsType> outStream
)
{
    const float Density = _BaseParams.x;
    const float Highlight = _BaseParams.z;

    // Input vertices
    AttributesMesh v0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh v1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh v2 = ConvertToAttributesMesh(input[2]);

    float3 p0_c = v0.positionOS;
    float3 p1_c = v1.positionOS;
    float3 p2_c = v2.positionOS;

#if SHADERPASS == SHADERPASS_VELOCITY
    bool hasDeformation = unity_MotionVectorsParams.x > 0.0;
    float3 p0_p = hasDeformation ? input[0].previousPositionOS : p0_c;
    float3 p1_p = hasDeformation ? input[1].previousPositionOS : p1_c;
    float3 p2_p = hasDeformation ? input[2].previousPositionOS : p2_c;
#else
    float3 p0_p = p0_c;
    float3 p1_p = p1_c;
    float3 p2_p = p2_c;
#endif

#ifdef ATTRIBUTES_NEED_NORMAL
    float3 n0 = v0.normalOS;
    float3 n1 = v1.normalOS;
    float3 n2 = v2.normalOS;
#else
    float3 n0 = 0;
    float3 n1 = 0;
    float3 n2 = 0;
#endif

    float3 center_c = (p0_c + p1_c + p2_c) / 3;
    float3 center_p = (p0_p + p1_p + p2_p) / 3;

    float param_c = AnimationParameter(_EffPlaneC, center_c, pid);
    float param_p = AnimationParameter(_EffPlaneP, center_p, pid);

    // Pass through the vertices if the animation hasn't been started.
    if (param_c == 0)
    {
        outStream.Append(VertexOutput(v0, p0_c, p0_p, n0));
        outStream.Append(VertexOutput(v1, p1_c, p1_p, n1));
        outStream.Append(VertexOutput(v2, p2_c, p2_p, n2));
        outStream.RestartStrip();
        return;
    }

    // Random selection
    if (Hash(pid * 877) > Density)
    {
        // Not selected: Simple scaling during [0.05, 0.1]
        param_c = smoothstep(0, 0.1, param_c);
        param_p = smoothstep(0, 0.1, param_p);

        p0_c = lerp(p0_c, center_c, param_c);
        p1_c = lerp(p1_c, center_c, param_c);
        p2_c = lerp(p2_c, center_c, param_c);

        p0_p = lerp(p0_p, center_p, param_p);
        p1_p = lerp(p1_p, center_p, param_p);
        p2_p = lerp(p2_p, center_p, param_p);

        outStream.Append(VertexOutput(v0, p0_c, p0_p, n0));
        outStream.Append(VertexOutput(v1, p1_c, p1_p, n1));
        outStream.Append(VertexOutput(v2, p2_c, p2_p, n2));
        outStream.RestartStrip();
        return;
    }

    // Triangle inflation (only visible at the beginning of the animation)
    const float Inflation = _AnimParams.x * 10;

    float inf_c = 1 + Inflation * smoothstep(0, 0.3, param_c);
    float inf_p = 1 + Inflation * smoothstep(0, 0.3, param_p);

    p0_c = lerp(center_c, p0_c, inf_c);
    p1_c = lerp(center_c, p1_c, inf_c);
    p2_c = lerp(center_c, p2_c, inf_c);

    p0_p = lerp(center_p, p0_p, inf_p);
    p1_p = lerp(center_p, p1_p, inf_p);
    p2_p = lerp(center_p, p2_p, inf_p);

    float3 cp_c = CylindricalCoord(center_c);
    float3 cp_p = CylindricalCoord(center_p);

    float ext = lerp(0, 2, Hash(pid * 701));
    cp_c.x *= 1 + ext * param_c;
    cp_p.x *= 1 + ext * param_p;

    float intensity = smoothstep(0.0, 0.3, param_c) + smoothstep(0.1, 0.6, param_c);
    // Pick some cells and stop their animation at 1.0 to highlight them.
    intensity = min(intensity, Hash(pid * 329) < Highlight ? 1 : 2);

    float rand = Hash(pid * 227);

    for (int i = 0; i < SEGMENT_COUNT; i++)
    {
        float seg_param = (float)i / SEGMENT_COUNT;

        SpiralPoint sp_c = GetSpiralPoint(cp_c, seg_param, param_c);
        SpiralPoint sp_p = GetSpiralPoint(cp_p, seg_param, param_p);

        float3 tp0_c = lerp(p0_c, p1_c, seg_param);
        float3 tp1_c = p2_c;

        float3 tp0_p = lerp(p0_c, p1_c, seg_param);
        float3 tp1_p = p2_c;

        // Triangle to spiral transformation
        half t2s_c = smoothstep(0, 0.6, param_c);
        half t2s_p = smoothstep(0, 0.6, param_p);

        tp0_c = lerp(tp0_c, sp_c.p0, t2s_c);
        tp1_c = lerp(tp1_c, sp_c.p1, t2s_c);

        tp0_p = lerp(tp0_p, sp_p.p0, t2s_p);
        tp1_p = lerp(tp1_p, sp_p.p1, t2s_p);

        outStream.Append(VertexOutput(v0, tp0_c, tp0_p, n0, intensity, rand, float2(0, 0.5)));
        outStream.Append(VertexOutput(v1, tp1_c, tp1_p, n1, intensity, rand, float2(1, 0.5)));
    }

    outStream.RestartStrip();
}
