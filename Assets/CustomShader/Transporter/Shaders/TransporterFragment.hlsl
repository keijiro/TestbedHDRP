half4 _EmissionHSVM;
half4 _EdgeHSVM;
half _HueShift;

half3 SelfEmission(FragInputs input)
{
    half2 quad = input.color.xy;
    half intensity = input.color.z;
    half random = input.color.w;

    // Edge detection
    half2 fw_quad = fwidth(quad);
    half2 edge2 = min(smoothstep(0, fw_quad * 2,     quad),
                      smoothstep(0, fw_quad * 2, 1 - quad));
    half edge = (1 - min(edge2.x, edge2.y)) * (quad.x >= 0);

    // Random hue shift
    half hueShift = (random - 0.5) * _HueShift;

    // Emission color
    half3 c1 = HsvToRgb(half3(_EmissionHSVM.x + hueShift, _EmissionHSVM.yz));
    c1 *= _EmissionHSVM.w * intensity;

    // Edge color
    half3 c2 = HsvToRgb(half3(_EdgeHSVM.x + hueShift, _EdgeHSVM.yz));
    c2 *= edge * _EdgeHSVM.w;

    return c1 + c2;
}

//
// This fragment shader is copy-pasted from
// HDRP/ShaderPass/ShaderPassGBuffer.hlsl
// There are only two modifications from the original shader.
//
// - Changed the function name.
// - Cancel normal mapping for voxels.
// - Added the self emission term.
//
void TransporterFragment(
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

    // Custom: Normal map cancelling
    bool useBump = (input.color.x < 0);
    surfaceData.normalWS = useBump ? surfaceData.normalWS : input.worldToTangent[2];
    surfaceData.tangentWS = useBump ? surfaceData.tangentWS : input.worldToTangent[0];

#ifdef DEBUG_DISPLAY
    ApplyDebugToSurfaceData(input.worldToTangent, surfaceData);
#endif

    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);

    PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

    float3 bakeDiffuseLighting = GetBakedDiffuseLighting(surfaceData, builtinData, bsdfData, preLightData);

    // Custom: Self emission term
    bakeDiffuseLighting += SelfEmission(input);

    ENCODE_INTO_GBUFFER(surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer);
    ENCODE_SHADOWMASK_INTO_GBUFFER(float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3), outShadowMaskBuffer);

#ifdef _DEPTHOFFSET_ON
    outputDepth = posInput.deviceDepth;
#endif
}
