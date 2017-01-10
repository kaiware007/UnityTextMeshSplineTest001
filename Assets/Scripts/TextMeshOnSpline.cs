using UnityEngine;
using System.Collections;
using CurveTools;

public class TextMeshOnSpline : MonoBehaviour {

    #region public member
    // TextMeshの参照
    public TextMesh text;

    // スプラインデータ
    public Spline spline;

    // TextMeshのFontMaterialのTextテクスチャーの参照
    public Texture texture;
    
    public Material mat;

    // Splineデータの頂点を書き込むテクスチャ
    public Texture2D splineTex;

    // Splineテクスチャ内での3次元スケール
    public Vector3 splineScale = Vector3.zero;

    // ディレイ
    public float delay = 0;

    // スピード
    public float speed = 1;
    #endregion

    #region private member
    private Material _mat;      // マテリアルの複製
    private float animeTime = 0;    // 生成時からの経過時間
    #endregion

    // Use this for initialization
    void Start () {

        // Renderer Componentに設定されている、TextMeshのTextテクスチャーを取得する
        Renderer rend = GetComponent<Renderer>();
        texture = rend.material.mainTexture;

        // マテリアルを複製する（複数TextMeshOnSplineを扱うときのために複製する）
        _mat = new Material(mat);
        _mat.mainTexture = texture;  // Textテクスチャーをマテリアルにセットする

        CreateSplineTexture();

        rend.material = _mat;    // Rendererのマテリアルを自分のマテリアルに差し替える
    }

    // 指定した数に近い、2^nの値を返す
    int AlignPow2(int a)
    {
        int i = 1;

        while (a > (i <<= 1))
            if (i == 0) break; // 無いと極限のとき無限ループ

        return i;
    }

    /// <summary>
    /// スプラインデータをテクスチャに書き込む
    /// </summary>
    void CreateSplineTexture()
    {
        // スプラインデータを書き込むテクスチャ生成
        int width = AlignPow2(spline.cps.Length);   // ２の乗数倍じゃないと参照がおかしくなる
        Debug.Log("Width " + width);
        splineTex = new Texture2D(width, 2, TextureFormat.RGBAFloat, false);
        splineTex.filterMode = FilterMode.Point;
        splineTex.wrapMode = TextureWrapMode.Repeat;
        //byte[] data = new byte[spline.cps.Length * 3];
        float maxX = 0;
        float maxY = 0;
        float maxZ = 0;

        // 座標の最大値（スケール）を計算
        // テクスチャには0～1までの値しか書き込めないので、取り出した後にスケールをかけて元の値に戻す
        Debug.Log("cps.Length " + spline.cps.Length);
        for (int i = 0; i < spline.cps.Length; i++)
        {
            Vector3 pos = spline.cps[i].position;
            if (maxX < Mathf.Abs(pos.x))
            {
                maxX = Mathf.Abs(pos.x);
            }
            if (maxY < Mathf.Abs(pos.y))
            {
                maxY = Mathf.Abs(pos.y);
            }
            if (maxZ < Mathf.Abs(pos.z))
            {
                maxZ = Mathf.Abs(pos.z);
            }
        }

        splineScale = new Vector3(maxX, maxY, maxZ);

        // テクスチャにスプラインデータを書き込む
        for (int i = 0; i < spline.cps.Length; i++)
        {
            // Position 
            // 3次元座標(X,Y,Z)を0～1の範囲のRGBに変換
            Vector3 pos = spline.cps[i].position;
            float r = pos.x / maxX * 0.5f + 0.5f;
            float g = pos.y / maxY * 0.5f + 0.5f;
            float b = pos.z / maxZ * 0.5f + 0.5f;

            Debug.Log("[" + i + "] Position " + r + ", " + g + ", " + b);
            splineTex.SetPixel(i, 0, new Color(r, g, b, 1));

            // normal 計算間違ってる
            Vector3 velocity = spline.Velosity(i).normalized;
            Vector3 tangent = Vector3.Cross(velocity, Vector3.up);
            Vector3 normal = Vector3.Cross(tangent, velocity);
            //Vector3 normal = velocity;

            r = normal.x * 0.5f + 0.5f;
            g = normal.y * 0.5f + 0.5f;
            b = normal.z * 0.5f + 0.5f;

            Debug.Log("[" + i + "] Normal" + r + ", " + g + ", " + b);
            splineTex.SetPixel(i, 1, new Color(r, g, b, 1));
        }
        splineTex.Apply();

        // マテリアルにパラメータをセット
        // 動的に変えたい場合は、Updateの中でマテリアルにセットし直すこと
        Debug.Log("splineScale  " + splineScale.x + ", " + splineScale.y + ", " + splineScale.z);
        _mat.SetTexture("_SplineTex", splineTex);
        _mat.SetVector("_SplineScale", splineScale);
        _mat.SetInt("_CPS_Length", spline.cps.Length);
        //_mat.SetVector("_Offset", transform.localPosition);
        _mat.SetFloat("_Delay", delay);
        _mat.SetFloat("_AnimeTime", animeTime);
        _mat.SetFloat("_Speed", speed);
    }

	// Update is called once per frame
	void Update () {
        // アニメーション時間更新
        animeTime += Time.deltaTime;
        _mat.SetFloat("_AnimeTime", animeTime);
    }
}
