export const srcVertexShader = `
attribute vec2 a_texCoord;
varying vec2 v_texCoord;
void main(void) {
    v_texCoord = a_texCoord;
    gl_Position = vec4((a_texCoord.x * 2.0) - 1.0, 1.0 - (a_texCoord.y * 2.0), 0, 1);
}`

export const srcFragmentShader = `
precision mediump float;

uniform float left;
uniform float width;

uniform sampler2D sampler0;
varying vec2 v_texCoord;
void main(void) {
    vec2 uv = v_texCoord;
    uv.x = (uv.x * width) + left;
    gl_FragColor = vec4(
        texture2D(sampler0, uv).x,
        texture2D(sampler0, uv).y,
        texture2D(sampler0, uv).z,
        1.0
    );
}`

export function createShaderProgram(gl: WebGLRenderingContext) {
    const vs = gl.createShader(gl.VERTEX_SHADER)
    if (vs == null) throw new Error("failed to create vertex shader")
    gl.shaderSource(vs, srcVertexShader)
    gl.compileShader(vs)
    if (!gl.getShaderParameter(vs, gl.COMPILE_STATUS)) {
        throw new Error("failed to compile vertex shader: " + gl.getShaderInfoLog(vs))
    }

    const fs = gl.createShader(gl.FRAGMENT_SHADER)
    if (fs == null) throw new Error("failed to create fragment shader")
    gl.shaderSource(fs, srcFragmentShader)
    gl.compileShader(fs)
    if (!gl.getShaderParameter(fs, gl.COMPILE_STATUS)) {
        throw new Error("failed to compile fragment shader: " + gl.getShaderInfoLog(fs))
    }

    const program = gl.createProgram()
    if (program == null) throw new Error("failed to create program")
    gl.attachShader(program, vs)
    gl.attachShader(program, fs)
    gl.linkProgram(program)
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        throw new Error("failed to link program: " + gl.getProgramInfoLog(program))
    }
    return program
}