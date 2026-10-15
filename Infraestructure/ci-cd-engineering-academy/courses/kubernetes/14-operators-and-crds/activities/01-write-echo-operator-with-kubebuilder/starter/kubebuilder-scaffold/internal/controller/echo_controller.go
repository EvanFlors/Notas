package controller

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	demov1alpha1 "example.com/echo-operator/api/v1alpha1"
)

// EchoReconciler reconciles an Echo object.
type EchoReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=demo.academy.io,resources=echoes,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=demo.academy.io,resources=echoes/status,verbs=get;update;patch
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete

func (r *EchoReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// --- Step 1: fetch the Echo CR ---
	// TODO (student): Get the Echo. If NotFound, return nil (CR was deleted;
	// GC will handle the owned ConfigMap via ownerReferences).
	var echo demov1alpha1.Echo
	// var echo demov1alpha1.Echo
	// if err := r.Get(ctx, req.NamespacedName, &echo); err != nil {
	//     return ctrl.Result{}, client.IgnoreNotFound(err)
	// }
	_ = echo
	_ = types.NamespacedName{}

	// --- Step 2: build the desired ConfigMap ---
	// TODO (student): build a *corev1.ConfigMap with:
	//   name:      echo.Name + "-echo"
	//   namespace: echo.Namespace
	//   data:      {"message": echo.Spec.Message}
	//   labels:    {"app.kubernetes.io/managed-by":"echo-operator",
	//               "echoes.demo.academy.io/name": echo.Name}
	var desired *corev1.ConfigMap
	_ = desired

	// --- Step 3: ownerReference ---
	// TODO (student): ctrl.SetControllerReference(&echo, desired, r.Scheme)

	// --- Step 4: create or update ---
	// TODO (student):
	//   var existing corev1.ConfigMap
	//   err := r.Get(ctx, client.ObjectKeyFromObject(desired), &existing)
	//   switch {
	//   case apierrors.IsNotFound(err): r.Create(ctx, desired)
	//   case err != nil:                return ctrl.Result{}, err
	//   default:
	//       if existing.Data["message"] != desired.Data["message"] {
	//           existing.Data = desired.Data
	//           r.Update(ctx, &existing)
	//       }
	//   }
	_ = apierrors.IsNotFound

	// --- Step 5: status subresource ---
	// TODO (student):
	//   echo.Status.ObservedMessage = echo.Spec.Message
	//   now := metav1.Now()
	//   echo.Status.LastReconciledAt = &now
	//   if err := r.Status().Update(ctx, &echo); err != nil {
	//       return ctrl.Result{}, err
	//   }
	_ = metav1.Now

	logger.Info("reconciled (NOTE: TODOs still pending)", "echo", req.NamespacedName)
	return ctrl.Result{}, nil
}

func (r *EchoReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&demov1alpha1.Echo{}).
		Owns(&corev1.ConfigMap{}).
		Complete(r)
}
