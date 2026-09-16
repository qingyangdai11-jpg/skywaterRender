// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Water"
{
	Properties
	{
		_ReflectionTex("ReflectionTex", 2D) = "white" {}
		_WaterNornal("WaterNornal", 2D) = "white" {}
		_NormalTilling("NormalTilling", Float) = 0
		_WaterSpeed("WaterSpeed", Float) = 1
		_WaterNoise("WaterNoise", Float) = 1
		_SpecSmoothness("SpecSmoothness", Range( 0.001 , 1)) = 0.1
		_SpecTint("SpecTint", Color) = (0,0,0,0)
		_SpecIntensity("SpecIntensity", Float) = 1
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" }
		Cull Back
		CGINCLUDE
		#include "UnityPBSLighting.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#pragma target 3.0
		#ifdef UNITY_PASS_SHADOWCASTER
			#undef INTERNAL_DATA
			#undef WorldReflectionVector
			#undef WorldNormalVector
			#define INTERNAL_DATA half3 internalSurfaceTtoW0; half3 internalSurfaceTtoW1; half3 internalSurfaceTtoW2;
			#define WorldReflectionVector(data,normal) reflect (data.worldRefl, half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal)))
			#define WorldNormalVector(data,normal) half3(dot(data.internalSurfaceTtoW0,normal), dot(data.internalSurfaceTtoW1,normal), dot(data.internalSurfaceTtoW2,normal))
		#endif
		struct Input
		{
			float4 screenPos;
			float3 worldNormal;
			INTERNAL_DATA
			float3 worldPos;
		};

		struct SurfaceOutputCustomLightingCustom
		{
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half Metallic;
			half Smoothness;
			half Occlusion;
			half Alpha;
			Input SurfInput;
			UnityGIInput GIData;
		};

		uniform sampler2D _ReflectionTex;
		uniform sampler2D _WaterNornal;
		uniform float _NormalTilling;
		uniform float _WaterSpeed;
		uniform float _WaterNoise;
		uniform float _SpecSmoothness;
		uniform float4 _SpecTint;
		uniform float _SpecIntensity;

		inline half4 LightingStandardCustomLighting( inout SurfaceOutputCustomLightingCustom s, half3 viewDir, UnityGI gi )
		{
			UnityGIInput data = s.GIData;
			Input i = s.SurfInput;
			half4 c = 0;
			float4 ase_screenPos = float4( i.screenPos.xyz , i.screenPos.w + 0.00000000001 );
			float4 ase_screenPosNorm = ase_screenPos / ase_screenPos.w;
			ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
			float3 ase_worldPos = i.worldPos;
			float2 temp_output_14_0 = ( (ase_worldPos).xz / _NormalTilling );
			float temp_output_17_0 = ( _Time.y * 0.1 * _WaterSpeed );
			float2 temp_output_33_0 = ( (( tex2D( _WaterNornal, ( temp_output_14_0 + temp_output_17_0 ) ) + float4( UnpackNormal( tex2D( _WaterNornal, ( ( temp_output_14_0 * 1.5 ) + ( temp_output_17_0 * -1.0 ) ) ) ) , 0.0 ) )).rg * 0.5 );
			float dotResult35 = dot( temp_output_33_0 , temp_output_33_0 );
			float3 appendResult38 = (float3(temp_output_33_0 , sqrt( ( 1.0 - dotResult35 ) )));
			float3 WaterNormal40 = (WorldNormalVector( i , appendResult38 ));
			float3 ase_vertex3Pos = mul( unity_WorldToObject, float4( i.worldPos , 1 ) );
			float4 unityObjectToClipPos45 = UnityObjectToClipPos( ase_vertex3Pos );
			float4 RflectColor49 = tex2D( _ReflectionTex, ( (ase_screenPosNorm).xy + ( ( (WaterNormal40).xz / ( 1.0 + unityObjectToClipPos45.w ) ) * _WaterNoise ) ) );
			float3 ase_worldViewDir = normalize( UnityWorldSpaceViewDir( ase_worldPos ) );
			#if defined(LIGHTMAP_ON) && UNITY_VERSION < 560 //aseld
			float3 ase_worldlightDir = 0;
			#else //aseld
			float3 ase_worldlightDir = normalize( UnityWorldSpaceLightDir( ase_worldPos ) );
			#endif //aseld
			float3 normalizeResult54 = normalize( ( ase_worldViewDir + ase_worldlightDir ) );
			float dotResult55 = dot( WaterNormal40 , normalizeResult54 );
			float4 SpecColor67 = ( ( pow( max( dotResult55 , 0.0 ) , ( _SpecSmoothness * 256.0 ) ) * _SpecTint ) * _SpecIntensity );
			c.rgb = ( RflectColor49 + 0 ).rgb;
			c.a = 1;
			return c;
		}

		inline void LightingStandardCustomLighting_GI( inout SurfaceOutputCustomLightingCustom s, UnityGIInput data, inout UnityGI gi )
		{
			s.GIData = data;
		}

		void surf( Input i , inout SurfaceOutputCustomLightingCustom o )
		{
			o.SurfInput = i;
			o.Normal = float3(0,0,1);
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf StandardCustomLighting keepalpha fullforwardshadows 

		ENDCG
		Pass
		{
			Name "ShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			#include "HLSLSupport.cginc"
			#if ( SHADER_API_D3D11 || SHADER_API_GLCORE || SHADER_API_GLES || SHADER_API_GLES3 || SHADER_API_METAL || SHADER_API_VULKAN )
				#define CAN_SKIP_VPOS
			#endif
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			struct v2f
			{
				V2F_SHADOW_CASTER;
				float4 screenPos : TEXCOORD1;
				float4 tSpace0 : TEXCOORD2;
				float4 tSpace1 : TEXCOORD3;
				float4 tSpace2 : TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert( appdata_full v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				UNITY_TRANSFER_INSTANCE_ID( v, o );
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				half3 worldTangent = UnityObjectToWorldDir( v.tangent.xyz );
				half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				half3 worldBinormal = cross( worldNormal, worldTangent ) * tangentSign;
				o.tSpace0 = float4( worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x );
				o.tSpace1 = float4( worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y );
				o.tSpace2 = float4( worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z );
				TRANSFER_SHADOW_CASTER_NORMALOFFSET( o )
				o.screenPos = ComputeScreenPos( o.pos );
				return o;
			}
			half4 frag( v2f IN
			#if !defined( CAN_SKIP_VPOS )
			, UNITY_VPOS_TYPE vpos : VPOS
			#endif
			) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				Input surfIN;
				UNITY_INITIALIZE_OUTPUT( Input, surfIN );
				float3 worldPos = float3( IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w );
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				surfIN.worldPos = worldPos;
				surfIN.worldNormal = float3( IN.tSpace0.z, IN.tSpace1.z, IN.tSpace2.z );
				surfIN.internalSurfaceTtoW0 = IN.tSpace0.xyz;
				surfIN.internalSurfaceTtoW1 = IN.tSpace1.xyz;
				surfIN.internalSurfaceTtoW2 = IN.tSpace2.xyz;
				surfIN.screenPos = IN.screenPos;
				SurfaceOutputCustomLightingCustom o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutputCustomLightingCustom, o )
				surf( surfIN, o );
				#if defined( CAN_SKIP_VPOS )
				float2 vpos = IN.pos;
				#endif
				SHADOW_CASTER_FRAGMENT( IN )
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18500
130.4;62.4;1334.4;1140.6;772.2665;1555.582;3.269853;True;False
Node;AmplifyShaderEditor.WorldPosInputsNode;12;-478.8579,-1242.224;Inherit;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SwizzleNode;13;-259.8578,-1217.224;Inherit;False;FLOAT2;0;2;2;3;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;18;-302.8578,-971.2244;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;15;-272.8578,-1116.224;Inherit;False;Property;_NormalTilling;NormalTilling;2;0;Create;True;0;0;False;0;False;0;8;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;19;-299.8578,-860.2244;Inherit;False;Constant;_Float0;Float 0;2;0;Create;True;0;0;False;0;False;0.1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;20;-288.8578,-744.2244;Inherit;False;Property;_WaterSpeed;WaterSpeed;3;0;Create;True;0;0;False;0;False;1;1.23;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;17;-93.85783,-898.2244;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;30;-72.59391,-737.6591;Inherit;False;Constant;_Float2;Float 2;5;0;Create;True;0;0;False;0;False;-1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;28;-86.59391,-1011.659;Inherit;False;Constant;_Float1;Float 1;5;0;Create;True;0;0;False;0;False;1.5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;14;-73.85783,-1220.224;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;29;113.4061,-871.6591;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;31;114.4061,-1006.659;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;16;117.1422,-1210.224;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;26;281.4061,-947.6591;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;25;430.4504,-967.6998;Inherit;True;Property;_TextureSample0;Texture Sample 0;1;0;Create;True;0;0;False;0;False;-1;None;a1c15fd7310885747a7e0997bb42a175;True;0;False;bump;Auto;True;Instance;11;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;11;294.0422,-1251.925;Inherit;True;Property;_WaterNornal;WaterNornal;1;0;Create;True;0;0;False;0;False;-1;None;a1c15fd7310885747a7e0997bb42a175;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;32;781.406,-961.6591;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT3;0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SwizzleNode;21;910.9222,-937.639;Inherit;False;FLOAT2;0;1;2;3;1;0;COLOR;0,0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;34;910.8021,-823.4822;Inherit;False;Constant;_Float3;Float 3;5;0;Create;True;0;0;False;0;False;0.5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;33;1083.802,-1051.482;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DotProductOpNode;35;1273.802,-972.4822;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;36;1409.802,-967.4822;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SqrtOpNode;37;1585.802,-966.4822;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;38;1718.802,-1048.482;Inherit;False;FLOAT3;4;0;FLOAT2;0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ViewDirInputsCoordNode;51;-1342.794,398.7825;Inherit;False;World;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldNormalVector;39;1946.429,-1027.59;Inherit;False;False;1;0;FLOAT3;0,0,1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldSpaceLightDirHlpNode;52;-1363.594,598.9824;Inherit;False;False;1;0;FLOAT;0;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.PosVertexDataNode;46;-1380.848,44.94086;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;53;-1115.294,468.9825;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;40;2210.61,-1005.578;Inherit;False;WaterNormal;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.UnityObjToClipPosHlpNode;45;-1168.848,60.94086;Inherit;False;1;0;FLOAT3;0,0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.NormalizeNode;54;-952.2938,446.0824;Inherit;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;41;-1032.906,-141.0278;Inherit;False;40;WaterNormal;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;48;-1147.848,-36.05916;Inherit;False;Constant;_Float4;Float 4;5;0;Create;True;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;56;-1007.394,328.5825;Inherit;False;40;WaterNormal;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;47;-941.8478,69.94086;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;61;-859.0179,669.5734;Inherit;False;Constant;_Float5;Float 5;6;0;Create;True;0;0;False;0;False;256;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DotProductOpNode;55;-744.7936,338.9826;Inherit;False;2;0;OBJECT;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SwizzleNode;42;-825.8073,-139.652;Inherit;False;FLOAT2;0;2;2;3;1;0;FLOAT3;0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;59;-915.0936,572.9825;Inherit;False;Property;_SpecSmoothness;SpecSmoothness;5;0;Create;True;0;0;False;0;False;0.1;0.01;0.001;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;23;-559.0731,15.30247;Inherit;False;Property;_WaterNoise;WaterNoise;4;0;Create;True;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;44;-662.8478,-63.05914;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ScreenPosInputsNode;9;-622.8371,-338.5575;Float;False;0;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMaxOpNode;57;-578.3937,342.8826;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;60;-593.0179,568.5734;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SwizzleNode;10;-391.7124,-334.8077;Inherit;False;FLOAT2;0;1;2;3;1;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;43;-362.706,-92.21722;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ColorNode;64;-402.4977,530.8214;Inherit;False;Property;_SpecTint;SpecTint;6;0;Create;True;0;0;False;0;False;0,0,0,0;0.953889,1,0.03207541,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PowerNode;58;-423.6936,381.8826;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;62;-223.7063,381.65;Inherit;False;2;2;0;FLOAT;0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;66;-156.4977,517.8214;Inherit;False;Property;_SpecIntensity;SpecIntensity;7;0;Create;True;0;0;False;0;False;1;0.7;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;24;-209.7459,-278.0786;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;1;-59.06145,-400.416;Inherit;True;Property;_ReflectionTex;ReflectionTex;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;65;-50.49768,400.8214;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;49;257.1478,-407.0838;Inherit;False;RflectColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;67;100.5023,415.8214;Inherit;False;SpecColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;50;742.7843,-418.0075;Inherit;False;49;RflectColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;69;747.5952,-312.771;Inherit;False;67;SpecColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;68;997.6646,-395.8989;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;OBJECT;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;8;1487.397,-576.1569;Float;False;True;-1;2;ASEMaterialInspector;0;0;CustomLighting;Water;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;Back;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Opaque;0.5;True;True;0;False;Opaque;;Geometry;All;14;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;0;0;False;-1;0;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;15;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;13;0;12;0
WireConnection;17;0;18;0
WireConnection;17;1;19;0
WireConnection;17;2;20;0
WireConnection;14;0;13;0
WireConnection;14;1;15;0
WireConnection;29;0;17;0
WireConnection;29;1;30;0
WireConnection;31;0;14;0
WireConnection;31;1;28;0
WireConnection;16;0;14;0
WireConnection;16;1;17;0
WireConnection;26;0;31;0
WireConnection;26;1;29;0
WireConnection;25;1;26;0
WireConnection;11;1;16;0
WireConnection;32;0;11;0
WireConnection;32;1;25;0
WireConnection;21;0;32;0
WireConnection;33;0;21;0
WireConnection;33;1;34;0
WireConnection;35;0;33;0
WireConnection;35;1;33;0
WireConnection;36;0;35;0
WireConnection;37;0;36;0
WireConnection;38;0;33;0
WireConnection;38;2;37;0
WireConnection;39;0;38;0
WireConnection;53;0;51;0
WireConnection;53;1;52;0
WireConnection;40;0;39;0
WireConnection;45;0;46;0
WireConnection;54;0;53;0
WireConnection;47;0;48;0
WireConnection;47;1;45;4
WireConnection;55;0;56;0
WireConnection;55;1;54;0
WireConnection;42;0;41;0
WireConnection;44;0;42;0
WireConnection;44;1;47;0
WireConnection;57;0;55;0
WireConnection;60;0;59;0
WireConnection;60;1;61;0
WireConnection;10;0;9;0
WireConnection;43;0;44;0
WireConnection;43;1;23;0
WireConnection;58;0;57;0
WireConnection;58;1;60;0
WireConnection;62;0;58;0
WireConnection;62;1;64;0
WireConnection;24;0;10;0
WireConnection;24;1;43;0
WireConnection;1;1;24;0
WireConnection;65;0;62;0
WireConnection;65;1;66;0
WireConnection;49;0;1;0
WireConnection;67;0;65;0
WireConnection;68;0;50;0
WireConnection;68;1;69;0
WireConnection;8;13;68;0
ASEEND*/
//CHKSM=FBE3A75E3AC0489EE783219542DE96A7470F6D0B