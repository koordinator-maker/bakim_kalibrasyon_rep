# core/admin_fix.py
from django.contrib import admin
from django.urls import reverse, NoReverseMatch

def patched_build_app_dict(self, request, label=None):
    """
    Admin app_list için geçici düzeltme
    """
    app_dict = {}
    
    if label:
        models = [m for m in self._registry.keys() if m._meta.app_label == label]
    else:
        models = self._registry.keys()
    
    for model in models:
        app_label = model._meta.app_label
        
        if app_label not in app_dict:
            app_dict[app_label] = {
                'name': app_label.title(),
                'app_label': app_label,
                'app_url': f'/admin/{app_label}/',  # Direkt URL
                'has_module_perms': request.user.has_module_perms(app_label),
                'models': [],
            }
        
        model_admin = self._registry.get(model)
        if model_admin and model_admin.has_module_permission(request):
            perms = model_admin.get_model_perms(request)
            
            model_dict = {
                'name': model._meta.verbose_name_plural,
                'object_name': model._meta.object_name,
                'perms': perms,
                'admin_url': f'/admin/{app_label}/{model._meta.model_name}/',
                'add_url': f'/admin/{app_label}/{model._meta.model_name}/add/' if perms.get('add') else None,
            }
            
            app_dict[app_label]['models'].append(model_dict)
    
    # Boş app'leri temizle
    app_dict = {k: v for k, v in app_dict.items() if v['models']}
    
    return app_dict

# Monkey patch uygula
admin.site._build_app_dict = lambda request, label=None: patched_build_app_dict(admin.site, request, label)