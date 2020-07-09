// Regenerator effect geometry shader
// https://github.com/keijiro/TestbedHDRP

#include "Packages/jp.keijiro.noiseshader/Shader/SimplexNoise3D.hlsl"

float3 _CellParams; // cell density, cell size, highlight probability
float2 _AnimParams; // inflation, stretch
float3 _CellSpace1;
float3 _CellSpace2;
float4 _EffectPlane;
float4 _EffectPlanePrev;
float _LocalTime;

// Calculate an animation parameter from an object space position.
float AnimationParameter(float4 plane, float3 positionOS, uint primitiveID)
{
    float3 positionWS = GetAbsolutePositionWS(TransformObjectToWorld(positionOS));
    float param = dot(plane.xyz, positionWS) - plane.w;
    float random = 1 + Hash(primitiveID * 761); // Random distribution
    return saturate(param * random);
}

// Cell animation function that calculates quad vertex positions and normal
// vector from a given triangle and parameters.
void CellAnimation(
    uint primitiveID, float param,
    // Input: triangle vertices and centroid
    float3 p_t0, float3 p_t1, float3 p_t2, float3 center,
    // Output: quad positions and normal vector
    out float3 p_q0, out float3 p_q1, out float3 p_q2, out float3 p_q3, out float3 n_q
)
{
    const float CellSize = _CellParams.y;
    const float Inflation = _AnimParams.x * 10;
    const float Stretch = _AnimParams.y;

    // Triangle inflation (only visible at the beginning of the animation)
    float inflation = 1 + Inflation * smoothstep(0, 0.3, param);
    p_t0 = lerp(center, p_t0, inflation);
    p_t1 = lerp(center, p_t1, inflation);
    p_t2 = lerp(center, p_t2, inflation);

    // Cell quad size
    float baseSize = CellSize * lerp(0.5, 1, Hash(primitiveID * 701));
    float scale = smoothstep(0.4, 1.6, param) * 2; // Ease-in, steep-out
    float3 cq_x = TransformWorldToObjectDir(_CellSpace1) * baseSize * (1 - scale);
    float3 cq_y = TransformWorldToObjectDir(_CellSpace2) * baseSize * (1 + scale * scale * Stretch);

    // Triangle to quad transformation
    half t2q = smoothstep(0, 0.6, param);
    p_q0 = lerp(p_t0, center - cq_x - cq_y, t2q);
    p_q1 = lerp(p_t1, center + cq_x - cq_y, t2q);
    p_q2 = lerp(p_t2, center - cq_x + cq_y, t2q);
    p_q3 = lerp(p_t2, center + cq_x + cq_y, t2q);

    // Normal vector recalculation
    n_q = normalize(cross(p_q1 - p_q0, p_q2 - p_q0));
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

// Geometry shader function body
[maxvertexcount(4)]
void RegeneratorGeometry(
    uint primitiveID : SV_PrimitiveID,
    triangle Attributes input[3],
    inout TriangleStream<PackedVaryingsType> outStream
)
{
    const float Density = _CellParams.x;
    const float Highlight = _CellParams.z;

    // Input vertices
    AttributesMesh v0 = ConvertToAttributesMesh(input[0]);
    AttributesMesh v1 = ConvertToAttributesMesh(input[1]);
    AttributesMesh v2 = ConvertToAttributesMesh(input[2]);

    float3 p0 = v0.positionOS;
    float3 p1 = v1.positionOS;
    float3 p2 = v2.positionOS;

#if SHADERPASS == SHADERPASS_MOTION_VECTORS
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
    float3 n0 = 0;
    float3 n1 = 0;
    float3 n2 = 0;
#endif

    float3 center = (p0 + p1 + p2) / 3;
    float3 center_prev = (p0_prev + p1_prev + p2_prev) / 3;

    float param = AnimationParameter(_EffectPlane, center, primitiveID);
    float param_prev = AnimationParameter(_EffectPlanePrev, center_prev, primitiveID);

    // Pass through the vertices if the animation hasn't been started.
    if (param == 0)
    {
        outStream.Append(VertexOutput(v0, p0, p0_prev, n0));
        outStream.Append(VertexOutput(v1, p1, p1_prev, n1));
        outStream.Append(VertexOutput(v2, p2, p2_prev, n2));
        outStream.RestartStrip();
        return;
    }

    // Random selection
    if (Hash(primitiveID * 877) > Density)
    {
        // Not selected: Simple scaling during [0.1, 0.4]
        param = smoothstep(0.1, 0.4, param);
        p0 = lerp(p0, center, param);
        p1 = lerp(p1, center, param);
        p2 = lerp(p2, center, param);

        param_prev = smoothstep(0.1, 0.4, param_prev);
        p0_prev = lerp(p0_prev, center_prev, param_prev);
        p1_prev = lerp(p1_prev, center_prev, param_prev);
        p2_prev = lerp(p2_prev, center_prev, param_prev);

        outStream.Append(VertexOutput(v0, p0, p0_prev, n0, param));
        outStream.Append(VertexOutput(v1, p1, p1_prev, n1, param));
        outStream.Append(VertexOutput(v2, p2, p2_prev, n2, param));
        outStream.RestartStrip();
        return;
    }

    // Cell animation
    float3 p_q0, p_q1, p_q2, p_q3, n_q;
    CellAnimation(
        primitiveID, param, p0, p1, p2, center,
        p_q0, p_q1, p_q2, p_q3, n_q
    );

    float3 p_q0_prev, p_q1_prev, p_q2_prev, p_q3_prev, n_q_prev;
    CellAnimation(
        primitiveID, param_prev, p0_prev, p1_prev, p2_prev, center_prev,
        p_q0_prev, p_q1_prev, p_q2_prev, p_q3_prev, n_q_prev
    );

    // Self emission parameter (0:off -> 1:emission -> 2:edge)
    float intensity = smoothstep(0.0, 0.3, param) + smoothstep(0.1, 0.6, param);
    // Pick some cells and stop their animation at 1.0 to highlight them.
    intensity = min(intensity, Hash(primitiveID * 329) < Highlight ? 1 : 2);

    // Output vertices
    half random = Hash(primitiveID * 227);
    outStream.Append(VertexOutput(v0, p_q0, p_q0_prev, n_q, intensity, random, half2(0, 0)));
    outStream.Append(VertexOutput(v1, p_q1, p_q1_prev, n_q, intensity, random, half2(1, 0)));
    outStream.Append(VertexOutput(v2, p_q2, p_q2_prev, n_q, intensity, random, half2(0, 1)));
    outStream.Append(VertexOutput(v2, p_q3, p_q3_prev, n_q, intensity, random, half2(1, 1)));
    outStream.RestartStrip();
}
