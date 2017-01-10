Shader "GUI/Text Shader on Spline" {
	Properties{
		_MainTex("Font Texture", 2D) = "white" {}
		_SplineTex("Spline Texture", 2D) = "white" {}
		_Color("Text Color", Color) = (1,1,1,1)
		_TextScaleOffset("Text Scale Offset", Range(0,1)) = 0.1
		_Delay("Delay", Float) = 0
		_Speed("Speed", Float) = 1
	}

	// メインの処理
	SubShader{

		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		Lighting Off Cull Off ZTest Always ZWrite Off Fog{ Mode Off }
		Blend SrcAlpha OneMinusSrcAlpha

		Pass{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11, Xbox360, OpenGL ES 2.0 because it uses unsized arrays
//#pragma exclude_renderers d3d11 xbox360 gles
#pragma vertex vert
#pragma fragment frag
#pragma fragmentoption ARB_precision_hint_fastest

#include "UnityCG.cginc"

			// 頂点シェーダーの入力データ
			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			// 頂点シェーダーからの出力データ
			struct v2f {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			sampler2D _MainTex;						// 文字のテクスチャー
			uniform float4 _MainTex_ST;
			sampler2D _SplineTex;					// Splineテクスチャー
			uniform float4 _SplineTex_ST;			// SplineテクスチャーのUVのループやオフセットなど
			uniform float4 _SplineTex_TexelSize;	// Splineテクスチャーの解像度など
			uniform fixed4 _Color;	// テキストの色

			int _CPS_Length = 1;	// Spline配列の長さ

			float3 _SplineScale;		// Splineの各座標軸のスケール
			//float3 _Offset;				// 
			float _TextScaleOffset;		// 文字列の長さの比率
			float _AnimeTime;			// 生成されてからの経過時間
			float _Delay;				// 遅延時間
			float _Speed;				// スクロール速度

			// ============================
			// Spline Function
			// Original C# Library "CurveTools" created by nobnak : https://github.com/nobnak/CurveTools
			// ============================
			// Get Control Point(Position)
			// i : Splineの制御点の番号
			// length : Spline配列の長さ
			float3 GetCP(int i, int length) {
				// 制御点のはみだしチェック. はみ出していたら範囲内に収める
				i = (i < 0) ? (i % length) + length : i % length;
				
				// Splineテクスチャから制御点の座標データを取り出す
				float3 col = tex2Dlod(_SplineTex, float4((float)i / (_SplineTex_TexelSize.z), 0, 0, 1));

				//float3 col = tex2Dlod(_SplineTex, float4((float)i / (length), 0, 0, 1));
				// 0～1の値を -1～+1 の範囲に復元して、_SplineScaleの倍率を掛けることで元のVector3に戻す
				col.r = (col.r - 0.5) * 2.0 * _SplineScale.x;	// r = x
				col.g = (col.g - 0.5) * 2.0 * _SplineScale.y;	// g = y
				col.b = (col.b - 0.5) * 2.0 * _SplineScale.z;	// b = z
				return col;
			}

			// Get Control Point(Normal)
			// 計算が間違っているので使えない...!
			float3 GetCPN(int i, int length) {
				i = (i < 0) ? (i % length) + length : i % length;

				float3 col = tex2Dlod(_SplineTex, float4((float)i / (_SplineTex_TexelSize.z), 1, 0, 1));
				//float3 col = tex2Dlod(_SplineTex, float4((float)i / (length), 1, 0, 1));
				col.r = (col.r - 0.5) * 2.0;
				col.g = (col.g - 0.5) * 2.0;
				col.b = (col.b - 0.5) * 2.0;
				return col;
			}

			// Splineテクスチャから制御点の座標を取得する
			// t : 制御点の番号(0～Spline配列の長さまで、小数点で指定することで中間の座標が取れる）
			// p0～p3 : tの前後の制御点の座標
			float3 Position(float t, float3 p0, float3 p1, float3 p2, float3 p3) {
				// CurveTools内の計算式そのままなのでよくわかりません！
				float tm1 = t - 1;
				float tm2 = tm1 * tm1;
				float t2 = t * t;

				float3 m1 = 0.5 * (p2 - p0);
				float3 m2 = 0.5 * (p3 - p1);

				return (1.0 + 2.0 * t) * tm2 * p1 + t * tm2 * m1 + t2 * (3.0 - 2.0 * t) * p2 + t2 * tm1 * m2;
			}

			// Splineテクスチャから制御点の座標を取得する
			// t : 制御点の番号(0～Spline配列の長さまで、小数点で指定することで中間の座標が取れる）
			float3 Position(float t) {
				int i = floor(t);
				t -= i;
				return Position(t, GetCP(i - 1, _CPS_Length), GetCP(i, _CPS_Length), GetCP(i + 1, _CPS_Length), GetCP(i + 2, _CPS_Length));
			}

			// 指定した制御点のSpline上の進行方向を取得する
			// t : 制御点の番号(0～Spline配列の長さまで、小数点で指定することで中間の座標が取れる）
			// p0～p3 : tの前後の制御点の座標
			float3 Velosity(float t, float3 p0, float3 p1, float3 p2, float3 p3) {
				// CurveTools内の計算式そのままなのでよくわかりません！
				float tm1 = t - 1;
				float t6tm1 = 6.0 * t * tm1;

				float3 m1 = 0.5 * (p2 - p0);
				float3 m2 = 0.5 * (p3 - p1);

				return t6tm1 * p1 + (3.0 * t - 1.0) * tm1 * m1 - t6tm1 * p2 + t * (3.0 * t - 2.0) * m2;
			}

			// 指定した制御点のSpline上の進行方向を取得する
			// t : 制御点の番号(0～Spline配列の長さまで、小数点で指定することで中間の座標が取れる）
			float3 Velosity(float t) {
				int i = floor(t);
				t -= i;
				return Velosity(t, GetCPN(i - 1, _CPS_Length), GetCPN(i, _CPS_Length), GetCPN(i + 1, _CPS_Length), GetCPN(i + 2, _CPS_Length));
			}

			// =================================
			// 頂点シェーダー
			// =================================
			v2f vert(appdata_t v)
			{
				v2f o;
				float4 basePos = float4(0, v.vertex.y, 0, v.vertex.w);	// 頂点座標からY座標だけ使う

				float time = _AnimeTime * _Speed - _Delay;
				float t = (time - v.vertex.x * _TextScaleOffset) % _CPS_Length;	// 参照する制御点の位置を計算、頂点のX座標と制御点の位置は比例する
				float4 pos = basePos + float4(Position(t), 0);
				//float3 normal = Velosity(t) * 2;
				
				//pos += float4(normal, 0);
				o.vertex = mul(UNITY_MATRIX_MVP, pos);	// 求めた座標にModel View Projection Matrixを掛けてスクリーン座標にする
				
				o.color = v.color * _Color;	// 文字の色設定
				//o.color = float4(normal, 1);
				
				o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);	// 文字テクスチャのUVを割り当てる
				return o;
			}

			// =================================
			// Fragmentシェーダー (Pixelシェーダー) 
			// =================================
			fixed4 frag(v2f i) : COLOR
			{
				fixed4 col = i.color;
				col.a *= UNITY_SAMPLE_1CHANNEL(_MainTex, i.texcoord);	// アルファ値を設定
				return col;
			}	
			ENDCG
		}

	}

	// メインのSubShaderがエラーになった場合の代替処理
	SubShader{
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		Lighting Off Cull Off ZTest Always ZWrite Off Fog{ Mode Off }
		Blend SrcAlpha OneMinusSrcAlpha
			
		BindChannels{
			Bind "Color", color
			Bind "Vertex", vertex
			Bind "TexCoord", texcoord
		}
		Pass{
			SetTexture[_MainTex]{
				constantColor[_Color] combine constant * primary, constant * texture
			}
		}
	}
}