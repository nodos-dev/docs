# **Running AI Models**
Nodos support both AI Model inference and optimization with TensorRT. 
One could use AIModelLoader node, which can be found in ML->AI Models->AI MOdel Loader in the context menu with the right click.
This node required the Model Path, which is path to any ONNX Model (with ONNXRuntime 1.16 supports). 
![alt text]({{ remote_images_folder }}AIModelLoader_Node.png?raw=true)

For ONNXRunLocation, we suggest using TensorRT and enabling FP16 Optimization in general, but some models may not be suitable for TensorRT. In that case, model load will fail and you get the corresponding error log in the Log pane for the reasons of fail.

**Note that** optimization may take some time, and for the AI Models with dynamic input/output (models where any dimension of the i/o tensors is -1), the optimization will be performed during the output tensor determination. In other words, when you first conenct an input to the model. During that time the node status message "Determining Output Tensor Info..." will be displayed.

For more advanced and performant applications, the Stream pin would come handy; this provides full GPU async operation of the AI Model Inference pipeline for that specific stream. But **you must set the Stream pin before clicking to "LoadModel" button**.

After loading the model, we can connect the Model pin to the **ONNXRunner** node to see the I/O information of the model.

![alt text]({{ remote_images_folder }}depthanything.png?raw=true)

In above figure one can observe that the loaded model has the Input Tensor called **"image"** with the shape (1, 3, -1, -1) and Output Tensor called **"depth"** with the dimensions (-1, 1, -1, -1).

In general, the Output Tensor strictly depends on the Input Tensor and it will be determined when the Input Tensor set.

Now lets discuss how we can create the image tensor within Nodos features.


## **Texture-Tensor Transformations**
It is well known that TensorRT and CUDA are not compatible with Vulkan data by nature, but in Nodos this is not problem thanks to our Texture-to-Tensor and Tensor-to-Texture nodes.

Users first must understand the nature of their tensor requested by the AI Model, this information is hidden in the **"element_type"** field of the Tensor Pins.

![alt text]({{ remote_images_folder }}image_tensor.png?raw=true)

In the Figure above we see that the element type of the image tensor is "float", which corresponds to 32 bit per elements. So, we must ensure that the texture we want to use for our model is compatible with this data format.
To do that, one can either use a texture with R32G32B32A32_SFLOAT type or make use of another handy Nodos feature: **Texture Format Converter Node**.

First, lets create a **Texture Format Converter Node** and select the OutputFormat parameter as **R32G32B32A32_SFLOAT**.

![alt text]({{ remote_images_folder }}texture_format_converter.png?raw=true)


Then create **TextureToTensor** node and connect the TextureFormatConverter's output to the TextureToTensor's input.

![alt text]({{ remote_images_folder }}texture_to_tensor.png?raw=true)

Now remember that the **"image"** input of the our AI Model was requesting a tensor with shape (1, 3, -1, -1), this also known as NCHW layout where the 1st dimension corresponds to Batch, 2nd dimension corresponds to Channel, 3rd dimension is Height and 4th dimension is Width.

And also observe that our **TextureToTensor** node has **NHWC** Layout. Now lets change that to **NCHW** and also since our model requires 3 channel image also change the Output Format parameter of TextureToTensor to **RGB** from RGBA.

![alt text]({{ remote_images_folder }}texture_to_tensor2.png?raw=true)

Observe that now the OutputTensor has the shape (1,3,1080,1920) and this shape is compatible with our AI Model's input.

Now we can begin the TensorRT optimization (since we have dynamic input model) by connecting this tensor to our model.

![alt text]({{ remote_images_folder }}determining_output_tensor.png?raw=true)


After these steps, now we can connect the **"depth"** pin of our AI Model to TensorToTexture node with similar adjustments: choose the **NCHW** layout and since our output image has only one channel enable **"EnforceFourChannelOutput"**.

![alt text]({{ remote_images_folder }}tensor_to_texture.png?raw=true)

Congratulations, now you can run any image-to-image AI model by following the same pipeline creation steps.

### **Useful Features**
If you are a curious about the GPU run time of your model, in the **ONNXRunner** Node properties you simply can enable **"Measure Time"** to see how long it takes for your model to run in **GPU**, you can open the Watch pane and read the ONNX Runner Elapsed Time and ONNX Runner AVG Elapsed Time fields (note that the values are in microseconds).

![alt text]({{ remote_images_folder }}performance_metrics.png?raw=true)


