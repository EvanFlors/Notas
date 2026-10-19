package org.acme.ci

// StandardBuild: dominio del step standardBuild().
//
// Implementa Serializable porque las instancias viven dentro del estado del
// pipeline CPS: cuando el controller cede la ejecucion (p. ej. en un input
// humano o un sleep), el objeto se serializa a disco. Sin Serializable, el
// pipeline estalla con NotSerializableException en el primer step que ceda.

class StandardBuild implements Serializable {

  private static final long serialVersionUID = 1L

  String image
  String registry = 'ghcr.io/acme'
  List<String> deploy = ['dev']
  boolean requireApproval = false

  StandardBuild(Map args) {
    this.image           = args.image
    this.registry        = args.registry        ?: this.registry
    this.deploy          = (args.deploy as List) ?: this.deploy
    this.requireApproval = args.requireApproval == null ? this.requireApproval : args.requireApproval
  }

  String imageRef() {
    String tag = System.getenv('BUILD_NUMBER') ?: 'local'
    return "${registry}/${image}:${tag}"
  }

  boolean deploysToProd() {
    return deploy?.contains('prod')
  }
}
