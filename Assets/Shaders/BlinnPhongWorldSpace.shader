Shader "LX/BlinnPhongWorldSpace"
{
	Properties
	{
		_Albedo("Albedo", Color) = (1.0, 1.0, 1.0, 1.0)
		_MainTex("Main Tex", 2D) = "white" {}
		_BumpMap("Bump Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1.0
		_Specular("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
		_Gloss("Gloss", Range(8.0, 256)) = 20
	}

	SubShader
	{

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// 应用到了光照衰减，因此需要使用这个宏
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			half4 _Albedo;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float _BumpScale;
			half4 _Specular;
			float _Gloss;

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 worldPos: TEXCOORD1;
				SHADOW_COORDS(2)
				// 切线空间->世界空间变换矩阵
				half3 T2W_row0 : TEXCOORD3;
				half3 T2W_row1 : TEXCOORD4;
				half3 T2W_row2 : TEXCOORD5;
				
			};

			v2f vert (a2v v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);

				// 转换纹理坐标
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

				// 计算顶点世界坐标
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// 计算世界空间下的TBN
				half3 worldTangent = UnityObjectToWorldDir(v.tangent).xyz;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal).xyz;
				half3 worldBionormal = cross(worldNormal, worldTangent) * v.tangent.w;

				o.T2W_row0 = fixed3(worldTangent.x, worldBionormal.x, worldNormal.x);
				o.T2W_row1 = fixed3(worldTangent.y, worldBionormal.y, worldNormal.y);
				o.T2W_row2 = fixed3(worldTangent.z, worldBionormal.z, worldNormal.z);

				TRANSFER_SHADOW(o);
				return o;
			}
			
			

			fixed4 frag (v2f i) : SV_Target
			{
				// 计算世界空间下的三个方向
				half3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				half3 worldNormal;  // 从法线贴图中获取法线向量，根据BumpScale进行归一化计算
				worldNormal.xy = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
				worldNormal.xy *= _BumpScale;
				worldNormal.z = sqrt(1.0 - saturate(dot(worldNormal.xy, worldNormal.xy))); // dot(worldNormal.xy, worldNormal.xy) = x^2 + y^2
				worldNormal = fixed3(dot(i.T2W_row0, worldNormal), dot(i.T2W_row1, worldNormal), dot(i.T2W_row2, worldNormal));

				// 计算albedo
				float3 albedo = _Albedo.xyz * tex2D(_MainTex, i.uv.xy).xyz * _LightColor0;

				// Amibient
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * albedo;
			
				// Diffuse
				half3 diffuse = saturate(dot(worldLightDir, worldNormal)) * albedo;

				// Specular
				half3 halfVec = normalize(worldViewDir + worldLightDir);
				half3 specular = pow(saturate(dot(halfVec, worldNormal)), _Gloss) * albedo * _Specular;

				// 计算阴影&光照衰减
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				return fixed4(ambient + (diffuse + specular) * atten, 1.0);
			}
			ENDCG
		}

		Pass
		{
			Tags{ "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			struct v2f
			{
				V2F_SHADOW_CASTER;
			};
	
			v2f vert(appdata_base v)
			{
				v2f o;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i);
			}
				ENDCG
			}
		}
}
