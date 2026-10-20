package org.acme.ci

// BuildContext: dominio del pipeline estandar.
//
// Implementa Serializable porque las instancias viven en el estado del
// pipeline CPS: cuando el controller suspende y reanuda un build (p. ej.
// esperando un input manual), el objeto se serializa a disco. Si falta
// Serializable, el pipeline estalla con NotSerializableException al
// cruzar un step que ceda la ejecucion.

class BuildContext implements Serializable {

  private static final long serialVersionUID = 1L

  String image
  String registry = 'ghcr.io/acme'
  List<String> deploy = []
  int timeoutMinutes = 20

  BuildContext(Map args) {
    this.image          = args.image
    this.registry       = args.registry       ?: this.registry
    this.deploy         = (args.deploy as List) ?: this.deploy
    this.timeoutMinutes = (args.timeoutMinutes as Integer) ?: this.timeoutMinutes
  }

  String imageRef() {
    String tag = System.getenv('BUILD_NUMBER') ?: 'local'
    return "${registry}/${image}:${tag}"
  }

  boolean deploysTo(String env) {
    return deploy?.contains(env)
  }
}
