Shader "Custom/BoxUV_TopSideBottom"
{
    Properties
    {
        _TopTex    ("Top Texture",    2D) = "white" {}
        _SideTex   ("Side Texture",   2D) = "white" {}
        _BottomTex ("Bottom Texture", 2D) = "white" {}
        _EdgeEps   ("判定閾値", Range(0,1)) = 0.8
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_TopTex);    SAMPLER(sampler_TopTex);
            TEXTURE2D(_SideTex);   SAMPLER(sampler_SideTex);
            TEXTURE2D(_BottomTex); SAMPLER(sampler_BottomTex);
            float _EdgeEps;

            struct Attributes
            {
                float4 posOS  : POSITION;
                float3 normOS : NORMAL;
            };
            struct Varyings
            {
                float4 posHCS  : SV_POSITION;
                float3 normWS  : TEXCOORD0;
                float3 posOS   : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.posHCS = TransformObjectToHClip(IN.posOS);
                OUT.normWS = TransformObjectToWorldNormal(IN.normOS);
                OUT.posOS  = IN.posOS.xyz;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float3 n   = normalize(IN.normWS);
                float3 pOS = IN.posOS;

                // 面マスク
                float topMask    = step(_EdgeEps,  n.y);
                float botMask    = step(_EdgeEps, -n.y);
                float sideMask   = 1.0 - topMask - botMask;

                // ── 側面 UV ─────────────────────────────────
                // 左右面なら XZ→(Z,Y)、前後面なら XZ→(X,Y)
                float2 uvSide;
                if (abs(n.x) > abs(n.z))
                {
                    // X軸側面 (左右)
                    uvSide = float2(pOS.z + 0.5, pOS.y + 0.5);
                    // +X は反転
                    if (n.x > 0) uvSide.x = 1.0 - uvSide.x;
                }
                else
                {
                    // Z軸側面 (前後)
                    uvSide = float2(pOS.x + 0.5, pOS.y + 0.5);
                    // -Z は反転
                    if (n.z < 0) uvSide.x = 1.0 - uvSide.x;
                }

                // ── 天面 UV ─────────────────────────────────
                // 天面はオブジェクトXZ平面をそのまま使い、
                // 前面(+Z) がテクスチャV=0側に来るようにZを反転
                float2 uvTop    = float2(pOS.x + 0.5,    0.5 - pOS.z);

                // ── 底面 UV ─────────────────────────────────
                // 底面はXZをそのまま
                float2 uvBottom = float2(pOS.x + 0.5,    pOS.z + 0.5);

                // サンプリング
                float4 cTop    = SAMPLE_TEXTURE2D(_TopTex,    sampler_TopTex,    uvTop);
                float4 cSide   = SAMPLE_TEXTURE2D(_SideTex,   sampler_SideTex,   uvSide);
                float4 cBottom = SAMPLE_TEXTURE2D(_BottomTex, sampler_BottomTex, uvBottom);

                return cTop  * topMask
                     + cSide * sideMask
                     + cBottom * botMask;
            }
            ENDHLSL
        }
    }
}
