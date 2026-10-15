// Reference solution of the Reconcile function.
// Paste this body into starter/kubebuilder-scaffold/internal/controller/echo_controller.go
// replacing all the `// TODO (student)` blocks.

package controller

/*

func (r *EchoReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // 1. Fetch the CR.
    var echo demov1alpha1.Echo
    if err := r.Get(ctx, req.NamespacedName, &echo); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 2. Build the desired ConfigMap.
    desired := &corev1.ConfigMap{
        ObjectMeta: metav1.ObjectMeta{
            Name:      echo.Name + "-echo",
            Namespace: echo.Namespace,
            Labels: map[string]string{
                "app.kubernetes.io/managed-by":    "echo-operator",
                "echoes.demo.academy.io/name":     echo.Name,
            },
        },
        Data: map[string]string{
            "message": echo.Spec.Message,
        },
    }

    // 3. ownerReference so GC removes the CM when the Echo is deleted.
    if err := ctrl.SetControllerReference(&echo, desired, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }

    // 4. Create or update (idempotent).
    var existing corev1.ConfigMap
    err := r.Get(ctx, client.ObjectKeyFromObject(desired), &existing)
    switch {
    case apierrors.IsNotFound(err):
        if err := r.Create(ctx, desired); err != nil {
            return ctrl.Result{}, err
        }
    case err != nil:
        return ctrl.Result{}, err
    default:
        if existing.Data["message"] != desired.Data["message"] {
            existing.Data = desired.Data
            if err := r.Update(ctx, &existing); err != nil {
                return ctrl.Result{}, err
            }
        }
    }

    // 5. Status via the /status subresource.
    now := metav1.Now()
    echo.Status.ObservedMessage = echo.Spec.Message
    echo.Status.LastReconciledAt = &now
    if err := r.Status().Update(ctx, &echo); err != nil {
        return ctrl.Result{}, err
    }

    logger.Info("reconciled", "echo", req.NamespacedName)
    return ctrl.Result{}, nil
}

*/
