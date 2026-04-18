import 'dart:ffi';

// ignore: implementation_imports
import 'package:vulkan/src/vulkan_header.dart';

import 'vulkan_library_loader.dart';

class VulkanRuntimeBindings {
  VulkanRuntimeBindings._({
    required this.loadedLibraryPath,
    required DynamicLibrary library,
  }) : vkCreateInstance = library.lookupFunction<
         VkCreateInstanceNative,
         VkCreateInstance
       >('vkCreateInstance'),
       vkDestroyInstance = library.lookupFunction<
         VkDestroyInstanceNative,
         VkDestroyInstance
       >('vkDestroyInstance'),
       vkEnumeratePhysicalDevices = library.lookupFunction<
         VkEnumeratePhysicalDevicesNative,
         VkEnumeratePhysicalDevices
       >('vkEnumeratePhysicalDevices'),
       vkGetPhysicalDeviceQueueFamilyProperties = library.lookupFunction<
         VkGetPhysicalDeviceQueueFamilyPropertiesNative,
         VkGetPhysicalDeviceQueueFamilyProperties
       >('vkGetPhysicalDeviceQueueFamilyProperties'),
       vkGetPhysicalDeviceMemoryProperties = library.lookupFunction<
         VkGetPhysicalDeviceMemoryPropertiesNative,
         VkGetPhysicalDeviceMemoryProperties
       >('vkGetPhysicalDeviceMemoryProperties'),
       vkEnumerateDeviceExtensionProperties = library.lookupFunction<
         VkEnumerateDeviceExtensionPropertiesNative,
         VkEnumerateDeviceExtensionProperties
       >('vkEnumerateDeviceExtensionProperties'),
       vkCreateDevice = library.lookupFunction<
         VkCreateDeviceNative,
         VkCreateDevice
       >('vkCreateDevice'),
       vkDestroyDevice = library.lookupFunction<
         VkDestroyDeviceNative,
         VkDestroyDevice
       >('vkDestroyDevice'),
       vkGetDeviceQueue = library.lookupFunction<
         VkGetDeviceQueueNative,
         VkGetDeviceQueue
       >('vkGetDeviceQueue'),
       vkAllocateMemory = library.lookupFunction<
         VkAllocateMemoryNative,
         VkAllocateMemory
       >('vkAllocateMemory'),
       vkFreeMemory = library.lookupFunction<VkFreeMemoryNative, VkFreeMemory>(
         'vkFreeMemory',
       ),
       vkMapMemory = library.lookupFunction<VkMapMemoryNative, VkMapMemory>(
         'vkMapMemory',
       ),
       vkUnmapMemory = library.lookupFunction<VkUnmapMemoryNative, VkUnmapMemory>(
         'vkUnmapMemory',
       ),
       vkQueueSubmit = library.lookupFunction<VkQueueSubmitNative, VkQueueSubmit>(
         'vkQueueSubmit',
       ),
       vkQueueWaitIdle = library.lookupFunction<
         VkQueueWaitIdleNative,
         VkQueueWaitIdle
       >('vkQueueWaitIdle'),
       vkCreateBuffer = library.lookupFunction<
         VkCreateBufferNative,
         VkCreateBuffer
       >('vkCreateBuffer'),
       vkDestroyBuffer = library.lookupFunction<
         VkDestroyBufferNative,
         VkDestroyBuffer
       >('vkDestroyBuffer'),
       vkGetBufferMemoryRequirements = library.lookupFunction<
         VkGetBufferMemoryRequirementsNative,
         VkGetBufferMemoryRequirements
       >('vkGetBufferMemoryRequirements'),
       vkBindBufferMemory = library.lookupFunction<
         VkBindBufferMemoryNative,
         VkBindBufferMemory
       >('vkBindBufferMemory'),
       vkCreateImage = library.lookupFunction<VkCreateImageNative, VkCreateImage>(
         'vkCreateImage',
       ),
       vkDestroyImage = library.lookupFunction<VkDestroyImageNative, VkDestroyImage>(
         'vkDestroyImage',
       ),
       vkGetImageMemoryRequirements = library.lookupFunction<
         VkGetImageMemoryRequirementsNative,
         VkGetImageMemoryRequirements
       >('vkGetImageMemoryRequirements'),
       vkBindImageMemory = library.lookupFunction<
         VkBindImageMemoryNative,
         VkBindImageMemory
       >('vkBindImageMemory'),
       vkCreateImageView = library.lookupFunction<
         VkCreateImageViewNative,
         VkCreateImageView
       >('vkCreateImageView'),
       vkDestroyImageView = library.lookupFunction<
         VkDestroyImageViewNative,
         VkDestroyImageView
       >('vkDestroyImageView'),
       vkCreateShaderModule = library.lookupFunction<
         VkCreateShaderModuleNative,
         VkCreateShaderModule
       >('vkCreateShaderModule'),
       vkDestroyShaderModule = library.lookupFunction<
         VkDestroyShaderModuleNative,
         VkDestroyShaderModule
       >('vkDestroyShaderModule'),
       vkCreateGraphicsPipelines = library.lookupFunction<
         VkCreateGraphicsPipelinesNative,
         VkCreateGraphicsPipelines
       >('vkCreateGraphicsPipelines'),
       vkDestroyPipeline = library.lookupFunction<
         VkDestroyPipelineNative,
         VkDestroyPipeline
       >('vkDestroyPipeline'),
       vkCreatePipelineLayout = library.lookupFunction<
         VkCreatePipelineLayoutNative,
         VkCreatePipelineLayout
       >('vkCreatePipelineLayout'),
       vkDestroyPipelineLayout = library.lookupFunction<
         VkDestroyPipelineLayoutNative,
         VkDestroyPipelineLayout
       >('vkDestroyPipelineLayout'),
       vkCreateSampler = library.lookupFunction<
         VkCreateSamplerNative,
         VkCreateSampler
       >('vkCreateSampler'),
       vkDestroySampler = library.lookupFunction<
         VkDestroySamplerNative,
         VkDestroySampler
       >('vkDestroySampler'),
       vkCreateDescriptorSetLayout = library.lookupFunction<
         VkCreateDescriptorSetLayoutNative,
         VkCreateDescriptorSetLayout
       >('vkCreateDescriptorSetLayout'),
       vkDestroyDescriptorSetLayout = library.lookupFunction<
         VkDestroyDescriptorSetLayoutNative,
         VkDestroyDescriptorSetLayout
       >('vkDestroyDescriptorSetLayout'),
       vkCreateDescriptorPool = library.lookupFunction<
         VkCreateDescriptorPoolNative,
         VkCreateDescriptorPool
       >('vkCreateDescriptorPool'),
       vkDestroyDescriptorPool = library.lookupFunction<
         VkDestroyDescriptorPoolNative,
         VkDestroyDescriptorPool
       >('vkDestroyDescriptorPool'),
       vkAllocateDescriptorSets = library.lookupFunction<
         VkAllocateDescriptorSetsNative,
         VkAllocateDescriptorSets
       >('vkAllocateDescriptorSets'),
       vkUpdateDescriptorSets = library.lookupFunction<
         VkUpdateDescriptorSetsNative,
         VkUpdateDescriptorSets
       >('vkUpdateDescriptorSets'),
       vkCreateFramebuffer = library.lookupFunction<
         VkCreateFramebufferNative,
         VkCreateFramebuffer
       >('vkCreateFramebuffer'),
       vkDestroyFramebuffer = library.lookupFunction<
         VkDestroyFramebufferNative,
         VkDestroyFramebuffer
       >('vkDestroyFramebuffer'),
       vkCreateRenderPass = library.lookupFunction<
         VkCreateRenderPassNative,
         VkCreateRenderPass
       >('vkCreateRenderPass'),
       vkDestroyRenderPass = library.lookupFunction<
         VkDestroyRenderPassNative,
         VkDestroyRenderPass
       >('vkDestroyRenderPass'),
       vkCreateCommandPool = library.lookupFunction<
         VkCreateCommandPoolNative,
         VkCreateCommandPool
       >('vkCreateCommandPool'),
       vkDestroyCommandPool = library.lookupFunction<
         VkDestroyCommandPoolNative,
         VkDestroyCommandPool
       >('vkDestroyCommandPool'),
       vkAllocateCommandBuffers = library.lookupFunction<
         VkAllocateCommandBuffersNative,
         VkAllocateCommandBuffers
       >('vkAllocateCommandBuffers'),
       vkFreeCommandBuffers = library.lookupFunction<
         VkFreeCommandBuffersNative,
         VkFreeCommandBuffers
       >('vkFreeCommandBuffers'),
       vkBeginCommandBuffer = library.lookupFunction<
         VkBeginCommandBufferNative,
         VkBeginCommandBuffer
       >('vkBeginCommandBuffer'),
       vkEndCommandBuffer = library.lookupFunction<
         VkEndCommandBufferNative,
         VkEndCommandBuffer
       >('vkEndCommandBuffer'),
       vkCmdBindPipeline = library.lookupFunction<
         VkCmdBindPipelineNative,
         VkCmdBindPipeline
       >('vkCmdBindPipeline'),
       vkCmdBindDescriptorSets = library.lookupFunction<
         VkCmdBindDescriptorSetsNative,
         VkCmdBindDescriptorSets
       >('vkCmdBindDescriptorSets'),
       vkCmdBeginRenderPass = library.lookupFunction<
         VkCmdBeginRenderPassNative,
         VkCmdBeginRenderPass
       >('vkCmdBeginRenderPass'),
       vkCmdEndRenderPass = library.lookupFunction<
         VkCmdEndRenderPassNative,
         VkCmdEndRenderPass
       >('vkCmdEndRenderPass'),
       vkCmdDraw = library.lookupFunction<VkCmdDrawNative, VkCmdDraw>(
         'vkCmdDraw',
       ),
       vkCmdCopyBufferToImage = library.lookupFunction<
         VkCmdCopyBufferToImageNative,
         VkCmdCopyBufferToImage
       >('vkCmdCopyBufferToImage'),
       vkCmdCopyImageToBuffer = library.lookupFunction<
         VkCmdCopyImageToBufferNative,
         VkCmdCopyImageToBuffer
       >('vkCmdCopyImageToBuffer'),
       vkCmdPipelineBarrier = library.lookupFunction<
         VkCmdPipelineBarrierNative,
         VkCmdPipelineBarrier
       >('vkCmdPipelineBarrier');

  factory VulkanRuntimeBindings.load() {
    final handle = VulkanLibraryLoader.openSystemLibrary();
    return VulkanRuntimeBindings._(
      loadedLibraryPath: handle.path,
      library: handle.library,
    );
  }

  final String loadedLibraryPath;

  final VkCreateInstance vkCreateInstance;
  final VkDestroyInstance vkDestroyInstance;
  final VkEnumeratePhysicalDevices vkEnumeratePhysicalDevices;
  final VkGetPhysicalDeviceQueueFamilyProperties
  vkGetPhysicalDeviceQueueFamilyProperties;
  final VkGetPhysicalDeviceMemoryProperties vkGetPhysicalDeviceMemoryProperties;
  final VkEnumerateDeviceExtensionProperties vkEnumerateDeviceExtensionProperties;
  final VkCreateDevice vkCreateDevice;
  final VkDestroyDevice vkDestroyDevice;
  final VkGetDeviceQueue vkGetDeviceQueue;
  final VkAllocateMemory vkAllocateMemory;
  final VkFreeMemory vkFreeMemory;
  final VkMapMemory vkMapMemory;
  final VkUnmapMemory vkUnmapMemory;
  final VkQueueSubmit vkQueueSubmit;
  final VkQueueWaitIdle vkQueueWaitIdle;
  final VkCreateBuffer vkCreateBuffer;
  final VkDestroyBuffer vkDestroyBuffer;
  final VkGetBufferMemoryRequirements vkGetBufferMemoryRequirements;
  final VkBindBufferMemory vkBindBufferMemory;
  final VkCreateImage vkCreateImage;
  final VkDestroyImage vkDestroyImage;
  final VkGetImageMemoryRequirements vkGetImageMemoryRequirements;
  final VkBindImageMemory vkBindImageMemory;
  final VkCreateImageView vkCreateImageView;
  final VkDestroyImageView vkDestroyImageView;
  final VkCreateShaderModule vkCreateShaderModule;
  final VkDestroyShaderModule vkDestroyShaderModule;
  final VkCreateGraphicsPipelines vkCreateGraphicsPipelines;
  final VkDestroyPipeline vkDestroyPipeline;
  final VkCreatePipelineLayout vkCreatePipelineLayout;
  final VkDestroyPipelineLayout vkDestroyPipelineLayout;
  final VkCreateSampler vkCreateSampler;
  final VkDestroySampler vkDestroySampler;
  final VkCreateDescriptorSetLayout vkCreateDescriptorSetLayout;
  final VkDestroyDescriptorSetLayout vkDestroyDescriptorSetLayout;
  final VkCreateDescriptorPool vkCreateDescriptorPool;
  final VkDestroyDescriptorPool vkDestroyDescriptorPool;
  final VkAllocateDescriptorSets vkAllocateDescriptorSets;
  final VkUpdateDescriptorSets vkUpdateDescriptorSets;
  final VkCreateFramebuffer vkCreateFramebuffer;
  final VkDestroyFramebuffer vkDestroyFramebuffer;
  final VkCreateRenderPass vkCreateRenderPass;
  final VkDestroyRenderPass vkDestroyRenderPass;
  final VkCreateCommandPool vkCreateCommandPool;
  final VkDestroyCommandPool vkDestroyCommandPool;
  final VkAllocateCommandBuffers vkAllocateCommandBuffers;
  final VkFreeCommandBuffers vkFreeCommandBuffers;
  final VkBeginCommandBuffer vkBeginCommandBuffer;
  final VkEndCommandBuffer vkEndCommandBuffer;
  final VkCmdBindPipeline vkCmdBindPipeline;
  final VkCmdBindDescriptorSets vkCmdBindDescriptorSets;
  final VkCmdBeginRenderPass vkCmdBeginRenderPass;
  final VkCmdEndRenderPass vkCmdEndRenderPass;
  final VkCmdDraw vkCmdDraw;
  final VkCmdCopyBufferToImage vkCmdCopyBufferToImage;
  final VkCmdCopyImageToBuffer vkCmdCopyImageToBuffer;
  final VkCmdPipelineBarrier vkCmdPipelineBarrier;
}
