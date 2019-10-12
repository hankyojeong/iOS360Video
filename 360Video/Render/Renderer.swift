//
//  Renderer.swift
//  360Video
//
//  Created by HanGyo Jeong on 09/10/2019.
//  Copyright © 2019 HanGyoJeong. All rights reserved.
//

import Foundation
import OpenGLES.ES3
import CoreVideo
import GLKit

class Renderer{
    let shader: Shader!
    let model: Sphere!
    let fieldOfView: Float = 60.0
    
    var context: EAGLContext!
    
    // VBO
    var vertexBuffer: GLuint = 0
    var texCoordBuffer: GLuint = 0
    var indexBuffer: GLuint = 0
    
    // VAO
    var vertexArray: GLuint = 0
    
    //Transform
    var modelViewProjectionMatrix = GLKMatrix4Identity
    var degree: Float = 0
    
    //Texture
    var lumaTexture: CVOpenGLESTexture?
    var chromaTexture: CVOpenGLESTexture?
    var videoTextureCache: CVOpenGLESTextureCache?
    
    init(context: EAGLContext, shader: Shader, model: Sphere){
        self.context = context
        self.shader = shader
        self.model = model
        
        createVBO()
        createVAO()
    }
    
    deinit {
        deleteVBO()
        deleteVAO()
    }
    
    func render(){
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        glUseProgram(shader.program)
        
        //Uniforms
        glUniformMatrix4fv(shader.modelViewProjectionMatrix, 1, GLboolean(GL_FALSE), modelViewProjectionMatrix.array)
        
        //Set the values of samplerY and samplerUV before rendering
        glUniform1i(GLint(shader.samplerY), 0)
        glUniform1i(GLint(shader.samplerUV), 1)
        
        glBindVertexArray(vertexArray)
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(model.indexCount), GLenum(GL_UNSIGNED_SHORT), nil)
        glBindVertexArray(0)
    }
    
    func updateModelViewProjectionMatrix(_ rotationX: Float, _ rotationY: Float){
        let aspect = abs(Float(UIScreen.main.bounds.size.width) / Float(UIScreen.main.bounds.size.height))
        let nearZ: Float = 0.1
        let farZ: Float = 100.0
        
        let fieldOfViewInRadians = GLKMathDegreesToRadians(fieldOfView)
        let projectionMatrix = GLKMatrix4MakePerspective(fieldOfViewInRadians, aspect, nearZ, farZ)
        
        //Apply the finger rotation in X-axis & Y-axis to the model view matrix
        var modelViewMatrix = GLKMatrix4Identity
        //Comment below line accurs translate your location to sphere's center
        //modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0, 0.0, -2.0)
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, rotationX)
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, rotationY)
        //degree += 0.0002
        //let rotateY = Float((sin(degree) + 1.0) / 2.0 * 360.0)
        
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
    }
    
    private func createVBO(){
        /*
         Create the space and put the real data
         */
        //Vertex
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(model.vertexCount * GLint(3 * MemoryLayout<GLfloat>.size)), model.vertices, GLenum(GL_STATIC_DRAW))
        
        //Texture Coordinates
        glGenBuffers(1, &texCoordBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(model.vertexCount * GLint(2 * MemoryLayout<GLfloat>.size)), model.texCoords, GLenum(GL_STATIC_DRAW))
        
        //Indices
        glGenBuffers(1, &indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLsizeiptr(model.indexCount * GLint(MemoryLayout<GLushort>.size)), model.indices, GLenum(GL_STATIC_DRAW))
    }
    private func createVAO(){
        glGenVertexArrays(1, &vertexArray)
        glBindVertexArray(vertexArray)
        
        //Bind variable between shader and buffer
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glEnableVertexAttribArray(shader.position)
        glVertexAttribPointer(shader.position, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 3), nil)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glEnableVertexAttribArray(shader.texCoord)
        glVertexAttribPointer(shader.texCoord, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GLfloat>.size * 2), nil)
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        
        glBindVertexArray(0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        
    }
    
    func updateTexture(_ pixelBuffer: CVPixelBuffer){
        //Create the CVOpenGLESTextureCache if it's not exist
        if videoTextureCache == nil{
            let result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &videoTextureCache)
            if result != kCVReturnSuccess{
                print("create CVOpenGLESTextureCacheCreate failure")
                return
            }
        }
        
        let textureWidth = GLsizei(CVPixelBufferGetWidth(pixelBuffer))
        let textureHeight = GLsizei(CVPixelBufferGetHeight(pixelBuffer))
        
        var result: CVReturn
        
        //Delete current textures
        cleanTextures()
        
        //Mapping the luma plane of a 420v buffer as a source texture
        glActiveTexture(GLenum(GL_TEXTURE0))
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache!,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_LUMINANCE,
                                                              textureWidth,
                                                              textureHeight,
                                                              GLenum(GL_LUMINANCE),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              0,
                                                              &lumaTexture)
        if result != kCVReturnSuccess {
            print("[lumaTexture]Create CVOpenGLESTextureCacheCreateTextureFromImage failure %d", result)
            return
        }
        glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture!), CVOpenGLESTextureGetName(lumaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        
        //Mapping the chroma plane of a 420v buffer as a source texture
        glActiveTexture(GLenum(GL_TEXTURE1))
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache!,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_LUMINANCE_ALPHA,
                                                              textureWidth / 2,
                                                              textureHeight / 2,
                                                              GLenum(GL_LUMINANCE_ALPHA),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              1,
                                                              &chromaTexture)
        if result != kCVReturnSuccess{
            print("[chromaTexture]Create CVOpenGLESTextureCacheCreateTextureFromImage failure %d", result)
            return
        }
        glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture!), CVOpenGLESTextureGetName(chromaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }
    
    private func cleanTextures(){
        if lumaTexture != nil{
            lumaTexture = nil
        }
        if chromaTexture != nil{
            chromaTexture = nil
        }
        if let videoTextureCache = videoTextureCache{
            CVOpenGLESTextureCacheFlush(videoTextureCache, 0)
        }
    }
    
    private func deleteVBO(){
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteBuffers(1, &texCoordBuffer)
        glDeleteBuffers(1, &indexBuffer)
    }
    private func deleteVAO(){
        glDeleteVertexArrays(1, &vertexArray)
    }
}
