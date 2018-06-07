Shader "Test Custom Shader"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)

        // _StencilRef = StencilLightingUsage.RegularLighting (2)
        [HideInInspector] _StencilRef("", Int) = 2

        // _StencilWriteMask = StencilBitMask.LightingMask (7)
        [HideInInspector] _StencilWriteMask("", Int) = 7
    }

    HLSLINCLUDE

    #pragma target 4.5

    #pragma vertex Vert
    #pragma fragment Frag

    #define UNITY_MATERIAL_LIT
    #define SURFACE_GRADIENT

    #include "CoreRP/ShaderLibrary/Common.hlsl"
    #include "HDRP/ShaderPass/FragInputs.hlsl"
    #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
    #include "HDRP/Material/Lit/LitProperties.hlsl"

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "HDLitShader" }
        Pass
        {
            Tags { "LightMode" = "GBuffer" }

            Stencil
            {
                WriteMask [_StencilWriteMask]
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM

            #define SHADERPASS SHADERPASS_GBUFFER
            #include "HDRP/ShaderVariables.hlsl"

            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD0

            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TANGENT_TO_WORLD
            #define VARYINGS_NEED_TEXCOORD0

            #include "HDRP/ShaderPass/VaryingMesh.hlsl"
            #include "HDRP/ShaderPass/VertMesh.hlsl"

            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/Lit/LitData.hlsl"

            half4 _Color;

            PackedVaryingsType Vert(AttributesMesh inputMesh)
            {
                VaryingsType varyingsType;
                varyingsType.vmesh = VertMesh(inputMesh);
                return PackVaryingsType(varyingsType);
            }

            void Frag(PackedVaryingsToPS packedInput, OUTPUT_GBUFFER(outGBuffer))
            {
                FragInputs input = UnpackVaryingsMeshToFragInputs(packedInput.vmesh);
                PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionWS);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);

                SurfaceData surfaceData;
                BuiltinData builtinData;
                GetSurfaceAndBuiltinData(input, V, posInput, surfaceData, builtinData);

                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(surfaceData);

                PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

                float3 bakeDiffuseLighting = GetBakedDiffuseLighting(surfaceData, builtinData, bsdfData, preLightData);
                bakeDiffuseLighting += frac(input.positionWS * 8);

                ENCODE_INTO_GBUFFER(surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer);
                ENCODE_SHADOWMASK_INTO_GBUFFER(float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3), outShadowMaskBuffer);
            }

            ENDHLSL
        }
    }
}
