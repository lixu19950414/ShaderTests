Shader "LX/PBR"
{
	Properties
	{
		_Albedo("Albedo Map", 2D) = "white" {}
		_Normal("Normal Map", 2D) = "bump"{}
		_NormalScale("Normal Scale", Range(-6.0, 6.0)) = 1.0
		_Metal("Metal Map",2D) = "black"{}
		_SmoothScale(" Smooth Scale", Range(0.0, 1.2)) = 1.0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"  
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			struct a2v
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float3 normal:NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				SHADOW_COORDS(1)
				float3 tangentLightDir : TEXCOORD2;
				float3 tangentViewDir : TEXCOORD3;
				float3 SHLighting : TEXCOORD4;
			};

			sampler2D _Albedo;
			sampler2D _Normal;
			float _NormalScale;
			sampler2D _Metal;
			float _SmoothScale;


			v2f vert(a2v v)
			{
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;

				TANGENT_SPACE_ROTATION;
				o.tangentLightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
				o.tangentViewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

				o.SHLighting = ShadeSH9(float4(UnityObjectToWorldNormal(v.normal), 1.0));

				TRANSFER_SHADOW(o);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// 计算各种方向
				float3 lightDirection = normalize(i.tangentLightDir);
				float3 viewDirection = normalize(i.tangentViewDir);
				float3 normalDirection = UnpackNormal(tex2D(_Normal, i.uv));
				normalDirection.xy *= _NormalScale;
				normalDirection.z = sqrt(1.0 - saturate(dot(normalDirection.xy, normalDirection.xy)));
				normalDirection = normalize(normalDirection);
				float3 h = normalize(lightDirection + viewDirection);

				// 计算各个夹角
				float NoL = saturate(dot(normalDirection, lightDirection));
				float NoV = saturate(dot(normalDirection, viewDirection));
				float NoH = saturate(dot(normalDirection, h));
				float VoH = saturate(dot(viewDirection, h));
				float LoH = saturate(dot(lightDirection, h));

				// 从通道图中取数据 r通道为metallic, alpha通道为smoothness，转到roughness
				half4 metalTex = tex2D(_Metal,i.uv);
				half metallic = metalTex.r;
				float smoothness = metalTex.a * _SmoothScale;
				float roughness = 1.0 - smoothness;

				// 计算a和a2以及f0
				float a = roughness * roughness;
				float a2 = a * a;
				float f0 = LoH * smoothness; // 菲涅尔系数，根据Disney的理论和LoH有关，还要和粗糙度有关，越光滑，菲涅尔系数是越高滴

				// 光照颜色
				float3 attenColor = SHADOW_ATTENUATION(i) * _LightColor0.xyz;

				// 反照率
				fixed4 albedo = tex2D(_Albedo, i.uv);

				// 计算diffuse的部分
				float3 directDiffuse = NoL * attenColor;
				float3 indirectDiffuse = i.SHLighting; // Indirect via SHLighting
				float3 diffuse = (directDiffuse + indirectDiffuse) * albedo * (1 - metallic);

				// 开始BRDF 喵喵喵？
				//                D(h) F(v,h) G(l,v,h)
				//f(l,v) = ---------------------------
				//                4(n·l)(n·v)

				//根据次表面原理（反正别人这么说的），halfvec = 次表面法线m
				//                alpha^2
				//D(m) = -----------------------------------
				//                pi*((n·m)^2 *(alpha^2-1)+1)^2

				float sqrtD = rcp(NoH * NoH * (a2 - 1) + 1);
				float D = a2 * sqrtD * sqrtD / 4;  // 在direct specular时，BRDF要乘PI，这里就直接约去

				// F(v,h)
				// float F = f0 + (1 - f0)*pow(2,(-5.55473 * VoH - 6.98316) * VoH); // Schlick逼近公式，取自UE4
				float F = f0 + (1 - f0) * pow((1 - LoH), 5);  // 标准Schlick公式，1 - LoH取自Disney

				//根据Smith Model G(l, v, h) = g(l) * g(v)，这个公式是Schlick的趋近公式，参数各有不同
				//                n·v
				//G(v) = -----------------
				//                (n·v) *(1-k) +k
				// 同理
				//                n·l
				//G(L) = -----------------
				//                (n·l) *(1-k) +k
				
				// float k = a2 * sqrt(2 / PI);           //Schlick-Beckmann
				// float k = a2 / 2;                      //Schlick-GGX
				float k = (a2 + 1) * (a2 + 1) / 8;	  //UE4

				// 简化G(l, v, h) / (n·l)(n·v)
				float GV = (NoV * (1 - k) + k);
				float GL = (NoL * (1 - k) + k);
				float G = rcp(GV * GL);

				fixed3 specularTerm = D * F * G;

				// fixed3 specular = albedo * attenColor * (1.0 / 3.1415926 + specularTerm) * NoL * metallic; //  1 / PI是BRDF公式的diffuse部分，MAGIC NUMBER，测试出来的，没有就会偏黑
				fixed3 specular = albedo * attenColor * (0.5 + specularTerm) * NoL * metallic; //  0.5是BRDF公式的diffuse部分，MAGIC NUMBER，测试出来的，没有就会偏黑

				fixed4 finalcolor;
				finalcolor.rgb = diffuse + specular;
				finalcolor.a = albedo.a;
				return finalcolor;
			}

			ENDCG
		}

		
	}

	FallBack "Diffuse"
}