from django.urls import path, include  # Import include
from django.contrib import admin
from Vision import views  # Import your app's views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/mymodels/', views.my_model_list, name='my_model_list'),
    path('api/mymodels/create/', views.my_model_create, name='my_model_create'),
    path('api/', include('Vision.urls')), # Include Vision app's URLs
    path('api/ai/', include('scheduler_ai.urls')), # Include scheduler_ai URLs
    path('scheduler/', include('scheduler_ai.urls')),
]

