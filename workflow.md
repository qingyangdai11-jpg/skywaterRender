# 天空与水面渲染项目 Workflow

本文根据项目当前的 Shader、ASE 节点、脚本和场景配置整理，按功能实现顺序记录制作方法、视觉效果与涉及的知识点。参数是编写时的配置快照；视觉收益属于方法目标，不代表已完成性能测量。

## 1. 项目目标与整体流程

我通过天空球、平面反射、动态法线、自定义高光和后处理，制作具有夕阳倒影及波纹变化的水面效果。

实现顺序：

**搭建天空环境 → 生成平面反射 → 水面采样反射贴图 → 添加动态波纹 → 计算高光 → 控制远处效果 → 后处理调整画面。**

需要区分三个处理阶段：

| 阶段 | 实现位置 | 处理对象 |
| --- | --- | --- |
| 水面着色 | `Assets/Water.shader` 的 ASE 节点 | 水面像素的反射扰动与高光 |
| 反射纹理模糊 | `PlanarReflection.cs` 与 `KawaseBlur.shader` | 反射相机生成的图像 |
| 相机后处理 | PostProcessLayer、PostProcessVolume、Profile | 相机渲染完成后的整幅画面 |

Bloom、调色不是在 Water 的 ASE 节点中完成的。

## 2. 统一渲染环境，搭建基础场景

### 实现方法

项目使用 Unity 2020.3，最终选择内置渲染管线 Built-in，以适配教程中的 ASE Surface Shader。当前使用的画质等级和 Graphics 设置采用内置管线；其他画质等级仍可能保留 URP 配置，切换等级时需要检查。

场景主要对象：

- **Main Camera**：观察场景，输出最终画面。
- **Directional Light**：提供自定义高光计算所需的光照方向。
- **SM_SkySphere**：承载天空贴图。
- **Water**：承载水面材质与平面反射脚本。

水面 Shader 前期使用 `Surface + Unlit` 显示反射，后续切换为 **Custom Lighting**，自行组合反射和高光。

### 解决的问题

项目早期出现洋红色，是因为内置管线 Surface Shader 被用于 URP。统一渲染管线后，Shader 才能按预期执行。安装 HDRP 并不能解决内置 Shader 与 URP 的不兼容问题。

**知识点：渲染管线兼容性、Shader 与材质的关系、Surface Shader、自定义光照。**

## 3. 使用 HDR 贴图制作天空背景

对应文件：[Skybox.shader](Assets/Skybox.shader)。

### 实现方法

我将天空贴图赋给天空球，使用模型 UV 采样纹理，并通过 `DecodeHDR` 解码天空颜色：

```hlsl
half4 col = tex2D(_MainTex, i.uv);
half3 col_hdr = DecodeHDR(col, _MainTex_HDR);
```

天空 Shader 直接输出纹理颜色，不计算普通物体的漫反射光照。

顶点变换到裁剪空间后，将深度调整到接近远裁剪面的位置，并使用 `UNITY_REVERSED_Z` 兼容不同深度方向。Shader 的渲染队列设置为 `Background`。

### 达到的效果

- 用天空贴图建立夕阳、云层和整体环境色。
- 使天空作为远处背景显示。
- 为反射相机提供可拍摄的天空内容。

天空图片中的太阳属于纹理内容，不会随 Directional Light 旋转。

**知识点：HDR 解码、UV 采样、裁剪空间、深度缓冲、Reversed-Z。**

## 4. 使用平面反射脚本生成倒影

对应文件：[PlanarReflection.cs](Assets/PlanarReflection.cs)。

### 脚本作用

根据观察相机与水面的关系生成镜像相机，将倒影渲染到 RenderTexture，再传给材质的 `_ReflectionTex`。

脚本负责“倒影图像从哪里来”，Water Shader 负责波纹扰动和高光。

### 4.1 确定反射平面

使用水面位置和 `transform.up` 构造平面方程：

```text
n · x + d = 0
```

其中 `n` 是平面法线，`d` 根据水面位置与 `_clipPlaneOffset` 计算。

### 4.2 构造反射矩阵与观察矩阵

`CalculateReflectionMatrix()` 根据平面构造反射矩阵 R。主相机的位置经 R 变换后得到镜像位置：

```text
p_reflection = R × p_camera
V_reflection = V_camera × R
```

代码将反射相机观察矩阵设置为：

```csharp
reflectCamera.worldToCameraMatrix =
    currentCam.worldToCameraMatrix * reflection;
```

这种方式从镜像视角重新渲染场景，能够随观察相机移动更新倒影，不是简单翻转一张图片。

### 4.3 使用斜裁剪投影限制反射范围

`CameraSpacePlane()` 将裁剪平面变换到反射相机空间；`CalculateObliqueMatrix()` 修改投影矩阵，使近裁剪边界贴合水面。

这样可以裁掉水面另一侧不应进入倒影的内容。`_clipPlaneOffset` 用于微调边界，缓解水面附近的裁剪瑕疵。

### 4.4 修正镜像后的面剔除

反射变换改变三角形绕序，所以在绘制反射时临时切换 `GL.invertCulling`，结束后恢复原状态。

### 4.5 渲染并传递纹理

反射相机将图像写入 RenderTexture，然后通过以下方式传给水面材质：

```csharp
_sharedMaterial.SetTexture("_ReflectionTex", texture);
```

脚本还包含以下控制：

- 使用 `_insideRendering` 防止反射递归触发。
- 过滤反射相机、预览相机及不符合条件的对象。
- 使用 `_reflectionMask` 控制反射相机绘制哪些层。
- 关闭反射相机自动渲染，由脚本显式触发。
- 使用 `try/finally` 恢复剔除状态和反射标记。
- 禁用组件时释放相机、纹理及模糊材质。

当前内置管线通过 `OnWillRenderObject()` 与 `Camera.Render()` 渲染。脚本还保留了 URP 分支：在 `beginCameraRendering` 中调用 `RenderSingleCamera()`。因此脚本仍引用 URP 类型，直接卸载 URP 包会导致编译问题。

**知识点：平面方程、反射矩阵、观察矩阵、投影矩阵、坐标空间转换、面剔除、离屏渲染。**

## 5. 在 ASE 中采样反射纹理

对应文件：[Water.shader](Assets/Water.shader)。

我在 ASE 中创建 `_ReflectionTex` 纹理属性，接收脚本输出的反射 RenderTexture。

当前 Shader 使用屏幕位置进行透视除法，构造采样坐标：

```text
UV_screen = ScreenPosition.xy / ScreenPosition.w
```

这让反射图按当前观察视角映射到水面，为后续 UV 扰动提供基础。

**知识点：屏幕空间 UV、齐次坐标、透视除法、脚本向材质传递纹理。**

## 6. 叠加两层滚动采样，制作动态波纹

### 实现方法

使用世界坐标 XZ 分量作为水面采样坐标：

```text
UV = WorldPosition.xz / NormalTilling
t = Time × 0.1 × WaterSpeed
UV_1 = UV + t
UV_2 = UV × 1.5 - t
```

通过两层不同尺度、相反方向的纹理运动，混合出用于构造水面法线的数据。

### 达到的效果

- 增加波纹变化，减轻单张纹理整体平移的感觉。
- 世界坐标采样使波纹尺度与场景空间关联，较少依赖模型自身 UV 拉伸。
- 用材质参数控制运动速度和波纹尺度。

| 参数 | 作用 |
| --- | --- |
| `_NormalTilling` | 控制采样尺度；当前使用除法，数值越大，纹理重复越疏 |
| `_WaterSpeed` | 控制波纹移动速度 |
| 第二层的 1.5 倍 UV | 产生不同尺度的波纹细节 |
| 第二层反向时间偏移 | 增加叠加变化 |

当前两层采样只有一层调用了 `UnpackNormal`，所以应描述为艺术化的法线扰动混合，不能称为严格的标准法线混合算法。

**知识点：世界空间映射、时间驱动 UV、纹理叠加、多尺度运动、法线贴图解码。**

## 7. 重建法线，并用法线扰动倒影

### 7.1 重建法线

取混合结果的 XY 分量，通过单位向量关系重建 Z：

```text
Nz = sqrt(1 - Nx² - Ny²)
```

再使用 ASE 的 World Normal 节点，将切线空间法线转换到世界空间，保存为 `WaterNormal`。

该公式要求 XY 的平方和不超过 1；当前代码没有对根号输入进行钳制，后续增强稳定性时可增加保护。

### 7.2 扰动反射 UV

```text
UV_reflection = UV_screen
              + WaterNormal.xz / (1 + ClipPosition.w) × WaterNoise
```

法线变化使反射图发生局部扭曲，表现水面波动。`_WaterNoise` 控制扰动强度；透视相机下，裁剪空间 W 与观察深度相关，使远处扰动趋于减弱。

这里改变的是采样位置，没有对水面网格做真实几何波浪位移。

**知识点：法线重建、切线空间到世界空间变换、UV 扰动、基于观察深度的衰减。**

## 8. 用 Blinn–Phong 思路计算水面高光

### 实现方法

取得世界空间视线方向 V、光源方向 L，以及水面法线 N。

```text
H = normalize(V + L)
Specular = max(dot(N, H), 0) ^ (SpecSmoothness × 256)
         × SpecTint × SpecIntensity
```

ASE 节点流程：

**View Direction + Light Direction → Normalize → 与 WaterNormal 做 Dot → Max → Power → 乘颜色和强度。**

### 达到的效果

- 灯光或观察方向变化时，高光位置变化。
- 波纹法线打散高光，形成水面亮点细节。
- 增大 `_SpecSmoothness` 会提高幂指数，使高光更集中。
- `_SpecTint` 控制高光色调，`_SpecIntensity` 控制高光亮度。

当前最终输出为：

```hlsl
c.rgb = (SpecColor67 + RflectColor49).rgb;
```

即 **自定义高光 + 平面反射颜色**。

### 调试经验

之前虽然 ASE 图中存在高光连线，但最终 Add 的输入类型出现 `OBJECT` 与 `COLOR` 不一致，生成代码曾变成“反射颜色 + 0”。检查生成代码帮助定位了高光丢失的位置。当前文件已经将高光结果加入最终输出。

### 当前实现边界

高光公式尚未乘灯光颜色，也没有应用阴影衰减。因此它是艺术化的方向高光，不能描述为完整的物理水面光照，也不能认为灯光 Intensity 已自动参与这套计算。

**知识点：Blinn–Phong 高光、半角向量、点积、幂函数、自定义光照合成、节点类型与代码生成。**

## 9. 使用距离衰减控制远处高光

计算水面像素到相机的距离，将 0～200 的距离映射为 1～0：

```text
Fade = clamp(1 - Distance / 200, 0, 1)
Specular_final = Specular × Fade
```

让高光随距离增加而减弱，目的是控制远处过强、过密的亮点，让近景细节与远景观感更协调。

这是视觉表现优化。Shader 仍然执行高光计算，不能将它描述为显著减少 GPU 运算。

**知识点：距离计算、范围映射、Clamp、视觉衰减。**

## 10. 对反射纹理执行 Kawase 模糊

对应文件：[KawaseBlur.shader](Assets/KawaseBlur.shader)。

### 实现方法

反射渲染完成后，`PlanarReflection.cs` 通过 CommandBuffer 对反射图进行模糊。

Kawase Shader 沿 UV 周围四个对角方向采样，再取平均：

```text
C = (C1 + C2 + C3 + C4) / 4
```

采样偏移由 `_Offset` 和 `_MainTex_TexelSize` 决定。

脚本准备两张临时 RenderTexture，在它们之间交替 Blit。每次循环执行两次模糊传递，最后写入模糊后的反射纹理，再赋给水面材质。

### 效果与性能取舍

- 模糊让倒影更柔和，减弱锐利细节。
- `_blurSize` 调整采样偏移。
- `_blurIterations` 控制循环次数；次数越多，模糊开销越大。
- `_downsample` 可降低反射纹理宽高，减少像素处理量，但会损失清晰度。

当前场景：模糊开启，`_blurSize = 2`，`_blurIterations = 1`，`_downsample = 1`。因此目前执行两次模糊 Blit，尚未使用降分辨率优化。

脚本会复用持久的反射纹理，并在命令完成后释放临时纹理和 CommandBuffer。不过当前纹理在创建后没有自动按相机尺寸变化重建，运行中调整分辨率或降采样参数时仍需留意。

**知识点：图像空间滤波、Kawase Blur、CommandBuffer、RenderTexture、双缓冲交替处理、降采样。**

## 11. 使用相机后处理统一最终画面

对应配置：[Main Camera Profile.asset](Assets/Scenes/SampleScene_Profiles/Main%20Camera%20Profile.asset)。

相机上配置了 PostProcessLayer 和全局 PostProcessVolume，二者通过层遮罩关联。后处理作用于整幅渲染画面，不是 Water Shader 内部的一部分。

### 11.1 Bloom：亮部扩散

当前配置：

- Intensity：`0.002`。
- Threshold：`3`。
- Dirt Intensity：`10`，并指定 Dirt Texture。

较高阈值主要提取较亮区域；当前强度较低，属于克制的亮部扩散。Dirt Texture 用于调制辉光的镜头污渍表现，其可见程度也受 Bloom 强度影响。

目的：使太阳、强反射和高光的亮部过渡更柔和。实际可见程度需要结合运行画面判断。

### 11.2 Color Grading：控制明暗层次

当前使用 HDR 调色模式和 **Custom Tonemapping**，通过 Toe、Shoulder 等参数控制暗部过渡及高亮压缩。

目的：协调天空、太阳与反射的亮度关系，将 HDR 亮度映射到显示范围。

当前 Profile 没有启用额外饱和度、色温、曝光覆盖，因此这些不列为已完成的调色操作。

### 11.3 SMAA：改善边缘锯齿

相机启用了 SMAA，用于减轻几何轮廓与部分高对比边缘的锯齿。

SMAA 不能完全消除细小水面高光的闪烁，需要与波纹尺度、高光宽度和距离衰减配合调整。

**知识点：HDR、Bloom、色调映射、后处理体积、层遮罩、SMAA 抗锯齿。**

## 12. 当前主要参数快照

| 模块 | 参数 | 当前值 | 作用 |
| --- | --- | --- | --- |
| 水面 | `_NormalTilling` | 6 | 波纹采样尺度 |
| 水面 | `_WaterSpeed` | 0.7 | 波纹运动速度 |
| 水面 | `_WaterNoise` | 5 | 反射扰动强度 |
| 水面 | `_SpecSmoothness` | 0.01 | 高光幂指数系数 |
| 水面 | `_SpecIntensity` | 0.7 | 自定义高光强度 |
| 水面 | `_SpecTint` | 暖橙色 | 高光色调 |
| 高光 | 衰减终点 | 200 | 远处高光减弱范围 |
| 反射 | `_blurSize` | 2 | 模糊采样偏移 |
| 反射 | `_blurIterations` | 1 | 两次模糊 Blit |
| 反射 | `_downsample` | 1 | 当前为原尺寸反射 |

## 13. 项目总结

我首先统一了项目的内置渲染管线环境，通过天空球与 HDR 贴图建立夕阳背景。随后使用平面反射脚本，根据水面平面构造反射矩阵，设置镜像相机的观察矩阵，并通过斜裁剪投影生成反射纹理。

在 ASE 中，我利用两层滚动纹理构建动态法线，对反射采样坐标进行扰动，表现水面的波纹与倒影变化。接着使用 Blinn–Phong 半角向量方法计算高光，并通过距离衰减控制远处亮点。

最后，结合反射纹理的 Kawase 模糊，以及相机端的 Bloom、色调映射和 SMAA，调整倒影柔和度、整体明暗层次与边缘质量。

**项目核心：矩阵生成随视角变化的平面反射，Shader 构造水面细节，后处理统一最终观感。**
