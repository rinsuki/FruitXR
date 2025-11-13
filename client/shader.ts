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
