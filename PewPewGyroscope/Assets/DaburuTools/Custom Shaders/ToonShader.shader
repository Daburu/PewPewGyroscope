Shader "_DaburuTools/Toon Shader"
{
    Properties 
    {
	    [Header(Common Properties)]
        _MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
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
    SubShader 
    {
    	// Drawing of the outline.
		Pass {
			Tags {"RenderType" = "Opaque"}
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


    
        Tags {"Queue" = "Geometry" "RenderType" = "Opaque"}
        Pass 
        {
            Tags {"LightMode" = "ForwardBase"}                      // This Pass tag is important or Unity may not give it the correct light information.
           	CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fwdbase                       // This line tells Unity to compile this pass for forward base.
                
                #include "UnityCG.cginc"
                #include "AutoLight.cginc"
               
               	struct vertex_input
               	{
               		half4 vertex : POSITION;
               		fixed3 normal : NORMAL;
               		fixed2 texcoord : TEXCOORD0;
               	};
                
                struct vertex_output
                {
                    half4  pos         : SV_POSITION;
                    fixed2  uv          : TEXCOORD0;
                    fixed3  lightDir    : TEXCOORD1;
                    fixed3  normal		: TEXCOORD2;
                    LIGHTING_COORDS(3,4)                            // Macro to send shadow & attenuation to the vertex shader.
                	half3  vertexLighting : TEXCOORD5;
                	fixed3	viewDir		: TEXCOORD6;
                };
                
                sampler2D _MainTex;
                fixed4 _MainTex_ST;
                fixed4 _Color;
                uniform fixed4 _UnlitColor;
				uniform fixed _DiffuseThreshold;
				uniform fixed _Diffusion;
				uniform fixed4 _SpecColor;
				uniform fixed _Shininess;
				uniform fixed _SpecDiffusion;

                fixed4 _LightColor0; 
                
                vertex_output vert (vertex_input v)
                {
                    vertex_output o;
                    o.pos = mul( UNITY_MATRIX_MVP, v.vertex);
                    o.uv = v.texcoord.xy;
					
					o.lightDir = ObjSpaceLightDir(v.vertex);
					
					o.normal = v.normal;

					o.viewDir = normalize( _WorldSpaceCameraPos.xyz - mul(_Object2World, v.vertex).xyz );
                    
                    TRANSFER_VERTEX_TO_FRAGMENT(o);                 // Macro to send shadow & attenuation to the fragment shader.
                    
                    o.vertexLighting = half3(0.0, 0.0, 0.0);
		            
		            #ifdef VERTEXLIGHT_ON
  					
  					fixed3 worldN = mul((fixed3x3)_Object2World, SCALED_NORMAL);
		          	half4 worldPos = mul(_Object2World, v.vertex);
		            
		            for (int index = 0; index < 4; index++)
		            {    
		               half4 lightPosition = half4(unity_4LightPosX0[index], 
		                  unity_4LightPosY0[index], 
		                  unity_4LightPosZ0[index], 1.0);
		 
		               half3 vertexToLightSource = half3(lightPosition - worldPos);        
		               
		               fixed3 lightDirection = normalize(vertexToLightSource);
		               
		               half squaredDistance = dot(vertexToLightSource, vertexToLightSource);
		               
		               fixed attenuation = 1.0 / (1.0  + unity_4LightAtten0[index] * squaredDistance);
		               
		               fixed3 diffuseReflection = attenuation * fixed3(unity_LightColor[index]) 
		                  * fixed3(_Color) * max(0.0, dot(worldN, lightDirection));         
		 
		               o.vertexLighting = o.vertexLighting + diffuseReflection * 2;
		            }
		                  
		         
		            #endif
                    
                    return o;
                }
                
                fixed4 frag(vertex_output i) : COLOR
                {
                    i.lightDir = normalize(i.lightDir);
                    fixed atten = LIGHT_ATTENUATION(i); // Macro to get you the combined shadow & attenuation value.
                    
                    fixed4 tex = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                    tex *= _Color + fixed4(i.vertexLighting, 1.0);

                    fixed nDotL = saturate(dot(i.normal, i.lightDir.xyz));

                    fixed diffuseCutoff = saturate( ( max(_DiffuseThreshold, nDotL) - _DiffuseThreshold ) * pow( (2 - _Diffusion), 10 ) );
                    fixed specularCutoff = saturate( (max(_Shininess, dot(reflect(-i.lightDir.xyz, i.normal), i.viewDir)) - _Shininess ) * pow((2 - _SpecDiffusion), 10));

                    fixed3 diffuseReflection = (1 - specularCutoff) * _Color.xyz * diffuseCutoff;
                    fixed3 specularReflection = _SpecColor.xyz * specularCutoff;
                    fixed3 ambientLight = (1 - diffuseCutoff) * _UnlitColor.xyz;

                    fixed3 lightFinal = (ambientLight + diffuseReflection) + specularReflection;
                                            
                    fixed4 c;
                    c.rgb = (tex.rgb * _LightColor0.rgb * lightFinal * atten) + (specularCutoff * (_Shininess - 0.5));
                    c.a = tex.a + _LightColor0.a * atten;
                    return c;
                }
            ENDCG
        }
 
        Pass {
            Tags {"LightMode" = "ForwardAdd"}                       // Again, this pass tag is important otherwise Unity may not give the correct light information.
            Blend One One                                           // Additively blend this pass with the previous one(s). This pass gets run once per pixel light.
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fwdadd                        // This line tells Unity to compile this pass for forward add, giving attenuation information for the light.
                
                #include "UnityCG.cginc"
                #include "AutoLight.cginc"
                
                struct v2f
                {
                    half4  pos         : SV_POSITION;
                    fixed2  uv          : TEXCOORD0;
                    fixed3  lightDir    : TEXCOORD2;
                    fixed3 normal		: TEXCOORD1;
                    LIGHTING_COORDS(3,4)                            // Macro to send shadow & attenuation to the vertex shader.
                };
 
                v2f vert (appdata_tan v)
                {
                    v2f o;
                    
                    o.pos = mul( UNITY_MATRIX_MVP, v.vertex);
                    o.uv = v.texcoord.xy;
                   	
					o.lightDir = ObjSpaceLightDir(v.vertex);
					
					o.normal =  v.normal;
                    TRANSFER_VERTEX_TO_FRAGMENT(o);                 // Macro to send shadow & attenuation to the fragment shader.
                    return o;
                }
 
                sampler2D _MainTex;
                fixed4 _MainTex_ST;
                fixed4 _Color;
 
                fixed4 _LightColor0; // Colour of the light used in this pass.
 
                fixed4 frag(v2f i) : COLOR
                {
                    i.lightDir = normalize(i.lightDir);
                    
                    fixed atten = LIGHT_ATTENUATION(i); // Macro to get you the combined shadow & attenuation value.
 
                    fixed4 tex = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                    
                    tex *= _Color;
                   
					fixed3 normal = i.normal;                    
                    fixed diff = saturate(dot(normal, i.lightDir));
                    
                    
                    fixed4 c;
                    c.rgb = (tex.rgb * _LightColor0.rgb * diff) * (atten * 2); // Diffuse and specular.
                    c.a = tex.a;
                    return c;
                }
            ENDCG
        }
    }
    //FallBack "VertexLit"    // Use VertexLit's shadow caster/receiver passes.
}