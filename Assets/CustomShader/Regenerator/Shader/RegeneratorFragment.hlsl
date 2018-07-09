// Regenerator effect fragment shader
// https://github.com/keijiro/TestbedHDRP

half4 _EmissionHSVM;
half4 _EdgeHSVM;
half _EdgeWidth;
half _HueShift;

// Self emission term (effect emission + edge detection)
half3 SelfEmission(FragInputs input)
{
    half2 quad = input.color.xy;
    half intensity = input.color.z; // 0:off -> 1:emission -> 2:edge
    half random = input.color.w;

    // Edge detection
    half2 edge2 = min(quad, 1 - quad) > fwidth(quad) * _EdgeWidth;
    half edge = (1 - min(edge2.x, edge2.y)) * (quad.x >= 0);

    // Random hue shift
    half hueShift = (random - 0.5) * 2 * _HueShift;

    // Emission color
    half3 c1 = HsvToRgb(half3(_EmissionHSVM.x + hueShift, _EmissionHSVM.yz));
    c1 *= _EmissionHSVM.w * saturate(intensity);

    // Edge color
    half3 c2 = HsvToRgb(half3(_EdgeHSVM.x + hueShift, _EdgeHSVM.yz));
    c2 *= edge * _EdgeHSVM.w;

    return lerp(c1, c2, saturate(intensity - 1));
}

// Fragment shader function, copy-pasted from HDRP/ShaderPass/ShaderPassGBuffer.hlsl
// There are a few modification from the original shader. See "Custom:" for details.
void RegeneratorFragment(
            PackedVaryingsToPS packedInput,
            OUTPUT_GBUFFER(outGBuffer)
            OUTPUT_GBUFFER_SHADOWMASK(outShadowMaskBuffer)
            #ifdef _DEPTHOFFSET_ON
            , out float outputDepth : SV_Depth
            #endif
            )
{
    FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);

    // input.positionSS is SV_Position
    PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionWS);

#ifdef VARYINGS_NEED_POSITION_WS
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
#else
    float3 V = 0; // Avoid the division by 0
#endif

    SurfaceData surfaceData;
    BuiltinData builtinData;
    GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

    // Custom: Cancel the normal map while the effect is active.
    float cancel = saturate(input.color.z);
    surfaceData.baseColor *= 1.0 - cancel;
    surfaceData.normalWS = lerp(surfaceData.normalWS, input.worldToTangent[2], cancel);
    surfaceData.tangentWS = lerp(surfaceData.tangentWS, input.worldToTangent[0], cancel);

#ifdef DEBUG_DISPLAY
    ApplyDebugToSurfaceData(input.worldToTangent, surfaceData);
#endif

    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

    PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

    float3 bakeDiffuseLighting = GetBakedDiffuseLighting(surfaceData, builtinData, bsdfData, preLightData);

    // Custom: Add the self emission term.
    bakeDiffuseLighting += SelfEmission(input);

    ENCODE_INTO_GBUFFER(surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer);
    ENCODE_SHADOWMASK_INTO_GBUFFER(float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3), outShadowMaskBuffer);

#ifdef _DEPTHOFFSET_ON
    outputDepth = posInput.deviceDepth;
#endif
}
