from django.urls import path
from . import views

urlpatterns = [
    path('generate_schedule/', views.GenerateScheduleView.as_view(), name='generate_schedule'),
    path('get_schedule/', views.GetScheduleView.as_view(), name='get_schedule'),
    path('generate_schedule_bqml/', views.generate_schedule_bqml, name='generate_schedule_bqml'), 
    path('delete_schedule/<int:pk>/', views.DeleteScheduleView.as_view(), name='delete_schedule'),
    path('update_schedule/<int:pk>/', views.UpdateScheduleView.as_view(), name='update_schedule'),
    path('generate_schedule_ai/', views.generate_schedule_ai, name='generate_schedule_ai'),
]