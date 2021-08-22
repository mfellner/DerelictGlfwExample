import std.conv;
import std.file;
import std.math;
import std.stdio;
import std.range;
import std.string;

import derelict.opengl;
import derelict.glfw3.glfw3;

import mfellner.exception;
import mfellner.math;

bool fullscreen = false;
bool animate    = false;

GLuint vertexLoc, colorLoc;
GLuint projMatrixLoc, viewMatrixLoc;

GLfloat[MATRIX_SIZE] projMatrix;
GLfloat[MATRIX_SIZE] viewMatrix;

GLuint[3] vao;

// Data for drawing Axis
GLfloat[] verticesAxis = [
-20.0,  0.0,  0.0f, 1.0,
 20.0,  0.0,  0.0f, 1.0,
  0.0,-20.0,  0.0f, 1.0,
  0.0, 20.0,  0.0f, 1.0,
  0.0,  0.0,-20.0f, 1.0,
  0.0,  0.0, 20.0f, 1.0];

GLfloat[] colorAxis = [
  1.0, 0.0, 0.0, 1.0,
  1.0, 0.0, 0.0, 1.0,
  0.0, 1.0, 0.0, 1.0,
  0.0, 1.0, 0.0, 1.0,
  0.0, 0.0, 1.0, 1.0,
  0.0, 0.0, 1.0, 1.0];

// Data for triangle 1
GLfloat[] vertices1 = [
 -3.0, -1.0, -5.0, 1.0,
 -1.0, -1.0, -5.0, 1.0,
 -2.0,  1.0, -5.0, 1.0];
 
GLfloat[] colors1 = [
  0.0, 1.0, 0.0, 1.0,
  1.0, 0.0, 0.0, 1.0,
  0.0, 0.0, 1.0, 1.0];

// Data for triangle 2
GLfloat[] vertices2 = [
  1.0, -1.0, -5.0, 1.0,
  3.0, -1.0, -5.0, 1.0,
  2.0,  1.0, -5.0, 1.0];

GLfloat[] colors2 = [
  0.0, 0.0, 1.0, 1.0,
  0.0, 1.0, 0.0, 1.0,
  1.0, 0.0, 0.0, 1.0];

void printProgramInfoLog(GLuint program) {
  GLint infologLength = 0;
  GLint charsWritten  = 0;

  glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infologLength);

  if (infologLength > 0) {
    char[] infoLog;
    glGetProgramInfoLog(program, infologLength, &charsWritten, infoLog.ptr);
    writeln(infoLog);
  } else {
    writeln("no program info log");
  }
}

string loadShader(string filename) {
  if (exists(filename) != 0) {
    return readText(filename);
  } else {
    throw new Exception("Shader file not found");
  }
}

GLuint compileShader(string filename, GLuint type) {
  const(char)* sp = loadShader(filename).toStringz();

  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &sp, null);
  glCompileShader(shader);

  GLint status;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    throw new Exception("Failed to compile shader");
  }

  GLint infologLength;
  glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infologLength);
  if (infologLength > 0) {
    char[] buffer = new char[infologLength];
    glGetShaderInfoLog(shader, infologLength, null, buffer.ptr);
    writeln(buffer);
  } else {
    writeln("no shader info log");
  }
  return shader;
}

nothrow void buildProjectionMatrix(GLfloat fov, GLfloat ratio, GLfloat nearP, GLfloat farP) {
  GLfloat f = 1.0 / tan (fov * (PI / 360.0));

  setIdentityMatrix(projMatrix, 4);

  projMatrix[        0] = f / ratio;
  projMatrix[1 * 4 + 1] = f;
  projMatrix[2 * 4 + 2] = (farP + nearP) / (nearP - farP);
  projMatrix[3 * 4 + 2] = (2.0 * farP * nearP) / (nearP - farP);
  projMatrix[2 * 4 + 3] = -1.0;
  projMatrix[3 * 4 + 3] =  0.0;
}

extern(C) nothrow void reshape(GLFWwindow* window, int width, int height) {
  if(height == 0) height = 1;
  glViewport(0, 0, width, height);
  GLfloat ratio = cast(GLfloat)width / cast(GLfloat)height;
  buildProjectionMatrix(60.0, ratio, 1.0, 30.0);
}

void setUniforms() {
    glUniformMatrix4fv(projMatrixLoc, 1, false, projMatrix.ptr);
    glUniformMatrix4fv(viewMatrixLoc, 1, false, viewMatrix.ptr);
}

void setCamera(GLfloat posX, GLfloat posY, GLfloat posZ, GLfloat lookAtX, GLfloat lookAtY, GLfloat lookAtZ) {
  GLfloat[VECTOR_SIZE]   dir;
  GLfloat[VECTOR_SIZE] right;
  GLfloat[VECTOR_SIZE]    up;

  up[0] = 0.0; up[1] = 1.0; up[2] = 0.0;

  dir[0] = (lookAtX - posX);
  dir[1] = (lookAtY - posY);
  dir[2] = (lookAtZ - posZ);
  normalize(dir);

  crossProduct(dir,up,right);
  normalize(right);

  crossProduct(right,dir,up);
  normalize(up);

  float[MATRIX_SIZE] aux;

  viewMatrix[0]  = right[0];
  viewMatrix[4]  = right[1];
  viewMatrix[8]  = right[2];
  viewMatrix[12] = 0.0;

  viewMatrix[1]  = up[0];
  viewMatrix[5]  = up[1];
  viewMatrix[9]  = up[2];
  viewMatrix[13] = 0.0;

  viewMatrix[2]  = -dir[0];
  viewMatrix[6]  = -dir[1];
  viewMatrix[10] = -dir[2];
  viewMatrix[14] =  0.0;

  viewMatrix[3]  = 0.0;
  viewMatrix[7]  = 0.0;
  viewMatrix[11] = 0.0;
  viewMatrix[15] = 1.0;

  setTranslationMatrix(aux, -posX, -posY, -posZ);

  multMatrix(viewMatrix, aux);
}

// adapted from http://open.gl/drawing and
// http://www.lighthouse3d.com/cg-topics/code-samples/opengl-3-3-glsl-1-5-sample
void main() {
  DerelictGL3.load();
  DerelictGLFW3.load();

  glfwSetErrorCallback(&glfwPrintError);

  if(!glfwInit()) {
    glfwTerminate();
    throw new Exception("Failed to create glcontext");
  }

  glfwWindowHint(GLFW_SAMPLES, 4);
  glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

  GLFWwindow* window;

  if (fullscreen) {
    window = glfwCreateWindow(640, 480, "Hello World", glfwGetPrimaryMonitor(), null);
  } else {
    window = glfwCreateWindow(640, 480, "Hello World", null, null);
  }

  if (!window) {
    glfwTerminate();
    throw new Exception("Failed to create window");
  }

  glfwSetFramebufferSizeCallback(window, &reshape);
  glfwMakeContextCurrent(window);

  DerelictGL3.reload();

  writefln("Vendor:   %s",   to!string(glGetString(GL_VENDOR)));
  writefln("Renderer: %s",   to!string(glGetString(GL_RENDERER)));
  writefln("Version:  %s",   to!string(glGetString(GL_VERSION)));
  writefln("GLSL:     %s\n", to!string(glGetString(GL_SHADING_LANGUAGE_VERSION)));

  glEnable(GL_DEPTH_TEST);

  //////////////////////////////////////////////////////////////////////////////
  // Prepare shader program
  GLuint vertexShader   = compileShader("source/shader/minimal.vert", GL_VERTEX_SHADER);
  GLuint fragmentShader = compileShader("source/shader/minimal.frag", GL_FRAGMENT_SHADER);

  GLuint shaderProgram = glCreateProgram();
  glAttachShader(shaderProgram, vertexShader);
  glAttachShader(shaderProgram, fragmentShader);
  glBindFragDataLocation(shaderProgram, 0, "outColor");
  glLinkProgram(shaderProgram);
  printProgramInfoLog(shaderProgram);

  vertexLoc = glGetAttribLocation(shaderProgram,"position");
  colorLoc = glGetAttribLocation(shaderProgram, "color"); 

  projMatrixLoc = glGetUniformLocation(shaderProgram, "projMatrix");
  viewMatrixLoc = glGetUniformLocation(shaderProgram, "viewMatrix");
  glCheckError();

  GLuint[2] vbo;
  glGenVertexArrays(3, vao.ptr);
  GLint            vSize = 4, cSize = 3;
  GLsizei         stride = 4 * float.sizeof;
  const GLvoid* cPointer = null; //cast(void*)(? * GLfloat.sizeof);

  //////////////////////////////////////////////////////////////////////////////
  // VAO for first triangle
  glBindVertexArray(vao[0]);
  // Generate two slots for the vertex and color buffers
  glGenBuffers(2, vbo.ptr);
  // bind buffer for vertices and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
  glBufferData(GL_ARRAY_BUFFER, vertices1.length * GLfloat.sizeof, vertices1.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(vertexLoc);
  glVertexAttribPointer(vertexLoc, vSize, GL_FLOAT, GL_FALSE, stride, null);
  // bind buffer for colors and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
  glBufferData(GL_ARRAY_BUFFER, colors1.length * GLfloat.sizeof, colors1.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(colorLoc);
  glVertexAttribPointer(colorLoc, cSize, GL_FLOAT, GL_FALSE, stride, cPointer);
  glCheckError();

  //////////////////////////////////////////////////////////////////////////////
  // VAO for second triangle
  glBindVertexArray(vao[1]);
  // Generate two slots for the vertex and color buffers
  glGenBuffers(2, vbo.ptr);
  // bind buffer for vertices and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
  glBufferData(GL_ARRAY_BUFFER, vertices2.length * GLfloat.sizeof, vertices2.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(vertexLoc);
  glVertexAttribPointer(vertexLoc, vSize, GL_FLOAT, GL_FALSE, stride, null);
  // bind buffer for colors and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
  glBufferData(GL_ARRAY_BUFFER, colors2.length * GLfloat.sizeof, colors2.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(colorLoc);
  glVertexAttribPointer(colorLoc, cSize, GL_FLOAT, GL_FALSE, stride, cPointer);
  glCheckError();
  
  //////////////////////////////////////////////////////////////////////////////
  // VAO for the Axis
  glBindVertexArray(vao[2]);
  // Generate two slots for the vertex and color buffers
  glGenBuffers(2, vbo.ptr);
  // bind buffer for vertices and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
  glBufferData(GL_ARRAY_BUFFER, verticesAxis.length * GLfloat.sizeof, verticesAxis.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(vertexLoc);
  glVertexAttribPointer(vertexLoc, vSize, GL_FLOAT, GL_FALSE, stride, null);
  // bind buffer for colors and copy data into buffer
  glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
  glBufferData(GL_ARRAY_BUFFER, colorAxis.length * GLfloat.sizeof, colorAxis.ptr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(colorLoc);
  glVertexAttribPointer(colorLoc, cSize, GL_FLOAT, GL_FALSE, stride, cPointer);
  glCheckError();

  int width, height;
  glfwGetWindowSize(window, &width, &height);
  reshape(window, width, height);

  int i = 0, k = 1;
  uint frame = 0;
  auto range = iota(-100, 100);
  GLfloat x = 0;

  while (!glfwWindowShouldClose(window)) {
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if(animate) {
      i = cast( int ) ( frame++ % range.length );
      k = i == 0 ? k * -1 : k;
      x = (range[i]) / cast(GLfloat)100 * k;
    }

    setCamera(4, 1, 4, x, 0, -1);
    glUseProgram(shaderProgram);
    setUniforms();

    glBindVertexArray(vao[0]);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glBindVertexArray(vao[1]);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glBindVertexArray(vao[2]);
    glDrawArrays(GL_LINES, 0, 6);

    glfwSwapBuffers(window);
    glfwPollEvents();

    if (fullscreen && glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
      glfwSetWindowShouldClose(window, GL_TRUE);
  }

  glDeleteProgram(shaderProgram);
  glDeleteShader(fragmentShader);
  glDeleteShader(vertexShader);
  glDeleteBuffers(1, vbo.ptr);
  glDeleteVertexArrays(1, vao.ptr);

  glfwDestroyWindow(window);
  glfwTerminate();
}
