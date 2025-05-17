# Vision/urls.py
from django.urls import path
from . import views
from .views import LoginView, RegisterView  # Import your views

urlpatterns = [
    path('api/login/', views.LoginView.as_view(), name='login'),
    path('api/register/', views.RegisterView.as_view(), name='register'),
    path('api/get_csrf_token/', views.get_csrf_token, name='get_csrf_token'),

]
