Shader "_DaburuTools/Toon Shader - Single Directional Light"{
	Properties {
		[Header(Common Properties)]
		_MainTex ("Diffuse Texture", 2D) = "white" {}
		_Color ("Lit Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_UnlitColor ("Unlit Color", Color) = (0.5, 0.5, 0.5, 1.0)
		_DiffuseThreshold ("Lighting Threshold", Range(0, 1)) = 0.15
		_Diffusion ("Diffusion", Range(0, 0.99)) = 0.4

		[Header(Specular Properties)]
		_SpecColor ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Shininess ("Shininess", Range(0.5, 0.99)) = 0.8
		_SpecDiffusion ("Specular Diffusion", Range(0, 0.99)) = 0.0

		[Header(Outline Properties)]
		_OutlineColor ("Outline Color", Color) = (0.0, 0.0, 0.0, 1.0)
		_OutlineThickness ("Outline Thickness", Range(0.0, 0.1)) = 0.03
	}
	SubShader {
		// Drawing of the outline.
		Pass {
			Tags {"RenderType"="Opaque"}
			Cull Front
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			//user defined variables
			uniform fixed4 _OutlineColor;
			uniform fixed _OutlineThickness;

			//base input structs
			struct vertexInput{
				half4 vertex : POSITION;
				fixed3 normal : NORMAL;
			};
			struct vertexOutput{
				half4 pos : SV_POSITION;
				fixed4 color : COLOR;
			};
			
			//vertex Function
			vertexOutput vert(vertexInput v){
				vertexOutput o;

				half4 newVertex = v.vertex + fixed4(v.normal * _OutlineThickness, 0.0);
				o.pos = mul(UNITY_MATRIX_MVP, newVertex);
				o.color = _OutlineColor;
				
				return o;
			}
			
			//fragment function
			fixed4 frag(vertexOutput i) : COLOR
			{
				return fixed4(i.color);
			}
			
			ENDCG
			
		}








		// Drawing of actual object itself
		Pass {
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			//user defined variables
			uniform sampler2D _MainTex;
			uniform fixed4 _MainTex_ST;
			uniform fixed4 _Color;
			uniform fixed4 _UnlitColor;
			uniform fixed _DiffuseThreshold;
			uniform fixed _Diffusion;
			uniform fixed4 _SpecColor;
			uniform fixed _Shininess;
			uniform fixed _SpecDiffusion;
			
			//unity defined variables
			uniform half4 _LightColor0;
			
			//base input structs
			struct vertexInput{
				half4 vertex : POSITION;
				fixed3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			struct vertexOutput{
				half4 pos : SV_POSITION;
				fixed3 normalDir : TEXCOORD0;
				fixed4 lightDir : TEXCOORD1;
				fixed3 viewDir : TEXCOORD2;
				float4 tex : TEXCOORD3;
			};
			
			//vertex Function
			vertexOutput vert(vertexInput v){
				vertexOutput o;
				
				//normalDirection
				o.normalDir = normalize( mul( half4( v.normal, 0.0 ), _World2Object ).xyz );
				
				//unity transform position
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				//texcoords
				o.tex = v.texcoord;
				
				//world position
				half4 posWorld = mul(_Object2World, v.vertex);

				//view direction
				o.viewDir = normalize( _WorldSpaceCameraPos.xyz - posWorld.xyz );

				//light direction
				half3 fragmentToLightSource = _WorldSpaceLightPos0.xyz - posWorld.xyz;
				o.lightDir = fixed4(
					normalize( lerp(_WorldSpaceLightPos0.xyz , fragmentToLightSource, _WorldSpaceLightPos0.w) ),
					lerp(1.0 , 1.0/length(fragmentToLightSource), _WorldSpaceLightPos0.w)
				);
				
				return o;
			}
			
			//fragment function
			fixed4 frag(vertexOutput i) : COLOR
			{
				//Lighting
				//dot product
				fixed nDotL = saturate(dot(i.normalDir, i.lightDir.xyz));

				fixed diffuseCutoff = saturate( ( max(_DiffuseThreshold, nDotL) - _DiffuseThreshold ) * pow( (2 - _Diffusion), 10 ) );
				fixed specularCutoff = saturate( (max(_Shininess, dot(reflect(-i.lightDir.xyz, i.normalDir), i.viewDir)) - _Shininess ) * pow((2 - _SpecDiffusion), 10));

				// calculate outlines
				fixed3 ambientLight = (1 - diffuseCutoff) * _UnlitColor.xyz;
				fixed3 diffuseReflection = _LightColor0.xyz * (1 - specularCutoff) * _Color.xyz * diffuseCutoff;
				fixed3 specularReflection = _SpecColor.xyz * specularCutoff;

				fixed3 lightFinal = (ambientLight + diffuseReflection) + specularReflection;

				float4 tex = tex2D(_MainTex, i.tex.xy * _MainTex_ST.xy + _MainTex_ST.zw);

				return fixed4(lightFinal * tex.xyz * _Color.xyz + (specularCutoff * (_Shininess - 0.5)), 1.0);
			}
			
			ENDCG
			
		}

	}
	//Fallback "Specular"
}