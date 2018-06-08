Shader "Test Custom Shader"
{
    Properties
    {
        _BaseColor("Color", Color) = (1, 1, 1, 1)
        _BaseColorMap("BaseColorMap", 2D) = "white" {}
        _Metallic("_Metallic", Range(0.0, 1.0)) = 0
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 1.0
        _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalScale("_NormalScale", Range(0.0, 2.0)) = 1

        [HideInInspector] _UVMappingMask("", Color) = (1, 0, 0, 0)

        // _StencilRef = StencilLightingUsage.RegularLighting (2)
        [HideInInspector] _StencilRef("", Int) = 2

        // _StencilWriteMask = StencilBitMask.LightingMask (7)
        [HideInInspector] _StencilWriteMask("", Int) = 7
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma require geometry

    #pragma vertex Vert
    #pragma geometry Geom
    #pragma fragment Frag

    #define _NORMALMAP_TANGENT_SPACE
    #define _NORMALMAP

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
            #include "CustomShader.hlsl"

            ENDHLSL
        }
        Pass
        {
            Tags{ "LightMode" = "ShadowCaster" }

            ColorMask 0

            HLSLPROGRAM

            #define SHADERPASS SHADERPASS_SHADOWS
            #define USE_LEGACY_UNITY_MATRIX_VARIABLES
            #include "CustomShader.hlsl"

            ENDHLSL
        }
    }
}
