from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import ScheduleItem
from django.contrib.auth import get_user_model
from rest_framework import serializers
import datetime
from django.http import JsonResponse
#from google.cloud import bigquery
from django.shortcuts import get_object_or_404
from django.contrib.auth.mixins import LoginRequiredMixin
from rest_framework.parsers import JSONParser
from django.views.decorators.csrf import csrf_exempt
import json
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
import logging
#from google.cloud import aiplatform

logger = logging.getLogger(__name__)

class DeleteScheduleView(LoginRequiredMixin, APIView):
    def delete(self, request, pk):
        try:
            schedule_item = get_object_or_404(ScheduleItem, pk=pk, user=request.user)
            schedule_item.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            return Response({'error': f'Error deleting schedule item: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ScheduleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ScheduleItem
        fields = ['id', 'event_name', 'start_time', 'end_time', 'day_of_week']
        read_only_fields = ['id']

class GetScheduleView(APIView):
    def get(self, request):
        user = request.user
        print(f"Fetching for user: {user.id}")
        if not user.is_authenticated:
            return Response({'error': 'User not authenticated.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            schedule_items = ScheduleItem.objects.filter(user_id=user.id).order_by('day_of_week', 'start_time')
            serializer = ScheduleItemSerializer(schedule_items, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': f'Error fetching schedule: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class GenerateScheduleView(APIView):
    def post(self, request):
        user_text = request.data.get('user_text', '').strip()
        user = request.user

        if not user.is_authenticated:
            return Response({'error': 'User not authenticated.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not user_text:
            return Response({'error': 'Please provide user text.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            parts = user_text.split()
            if len(parts) < 3:
                return Response({'error': 'Invalid input format. Please use something like "Event Day HH:MM-HH:MM"'}, status=status.HTTP_400_BAD_REQUEST)

            event_name_parts = []
            day_str = ""
            time_range_str = ""

            for part in parts:
                if part.lower() in ['monday', 'mon', 'tuesday', 'tue', 'wednesday', 'wed', 'thursday', 'thu', 'friday', 'fri', 'saturday', 'sat', 'sunday', 'sun']:
                    day_str = part.lower()
                elif '-' in part and ':' in part:
                    time_range_str = part
                else:
                    event_name_parts.append(part)

            event_name = " ".join(event_name_parts).strip()

            day_mapping = {
                'sunday': 0, 'sun': 0,
                'monday': 1, 'mon': 1,
                'tuesday': 2, 'tue': 2,
                'wednesday': 3, 'wed': 3,
                'thursday': 4, 'thu': 4,
                'friday': 5, 'fri': 5,
                'saturday': 6, 'sat': 6,
            }

            day_of_week = day_mapping.get(day_str)
            if day_of_week is None:
                return Response({'error': f'Invalid day: {day_str}. Please use a valid day of the week.'}, status=status.HTTP_400_BAD_REQUEST)
            elif not 0 <= day_of_week <= 6:
                return Response({'error': 'Day of week must be between 0 and 6.'}, status=status.HTTP_400_BAD_REQUEST)

            time_parts = time_range_str.split('-')
            if len(time_parts) != 2:
                return Response({'error': 'Invalid time format. Please use HH:MM-HH:MM'}, status=status.HTTP_400_BAD_REQUEST)

            start_time_str = time_parts[0].strip()
            end_time_str = time_parts[1].strip()

            # Basic time format validation
            if not (len(start_time_str) == 5 and start_time_str[2] == ':' and start_time_str[:2].isdigit() and start_time_str[3:].isdigit() and
                    len(end_time_str) == 5 and end_time_str[2] == ':' and end_time_str[:2].isdigit() and end_time_str[3:].isdigit()):
                return Response({'error': 'Invalid time format. Please use HH:MM for start and end times.'}, status=status.HTTP_400_BAD_REQUEST)

            try:
                start_time = datetime.datetime.strptime(start_time_str, '%H:%M').time()
                end_time = datetime.datetime.strptime(end_time_str, '%H:%M').time()

                if end_time <= start_time:
                    return Response({'error': 'End time must be later than the start time.'}, status=status.HTTP_400_BAD_REQUEST)

            except ValueError:
                return Response({'error': 'Invalid time format. Please use HH:MM for start and end times.'}, status=status.HTTP_400_BAD_REQUEST)

            schedule_item = ScheduleItem(
                user=user,
                event_name=event_name,
                start_time=start_time_str,
                end_time=end_time_str,
                day_of_week=day_of_week
            )
            schedule_item.save()
            return Response({'message': 'Schedule item saved successfully.'}, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'error': f'Error processing input: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
def generate_schedule_bqml(request):
    if request.method == 'POST':
        user_text = request.POST.get('user_text', '')

        # Your BigQuery connection and query logic here
        project_id = "vision-458010"
        dataset_id = "Person_schedule"
        table_id = "Schedule2"

        client = bigquery.Client(project="vision-458010")

        query = f"""
            SELECT day_of_week, start_time, event_name, end_time
            FROM `{project_id}.{dataset_id}.{table_id}`
            LIMIT 100
        """

        try:
            query_job = client.query(query)
            rows = query_job.result()

            schedule_items_from_bq = []
            for row in rows:
                schedule_item = {
                'day_of_week': row.day_of_week,
                'start_time': row.start_time if row.start_time else None,
                'event_name': row.event_name,
                'end_time': row.end_time if row.end_time else None
            }
                schedule_items_from_bq.append(schedule_item)

            # Now you need to save these to your Django models (ScheduleItem)
            user = request.user
            if not user.is_authenticated:
                return JsonResponse({'error': 'User not authenticated.'}, status=401)

            saved_count = 0
            for item_data in schedule_items_from_bq:
                schedule_item = ScheduleItem(
                    user=user,
                    event_name=item_data['event_name'],
                    start_time=item_data['start_time'],
                    end_time=item_data['end_time'],
                    day_of_week=item_data['day_of_week']
                )
                schedule_item.save()
                saved_count += 1

            return JsonResponse({'message': f'{saved_count} schedule items generated and saved from BigQuery.'})

        except Exception as e:
            logger.error(f"BigQuery error: {e}")
            return JsonResponse({'error': str(e)}, status=500)
    else:
        return JsonResponse({'error': 'Invalid request method'}, status=400)
    

class UpdateScheduleView(LoginRequiredMixin, APIView):
    parser_classes = [JSONParser]

    def put(self, request, pk):
        try:
            schedule_item = get_object_or_404(ScheduleItem, pk=pk, user=request.user)
            serializer = ScheduleItemSerializer(schedule_item, data=request.data)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'error': f'Error updating schedule item: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def patch(self, request, pk):
        try:
            schedule_item = get_object_or_404(ScheduleItem, pk=pk, user=request.user)
            serializer = ScheduleItemSerializer(schedule_item, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'error': f'Error updating schedule item: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        


# Initialize Vertex AI client (ensure proper authentication)
#aiplatform.init(project="vision-458010", location="us-west2")
#endpoint_name = "your-deployed-endpoint-name"
# endpoint = aiplatform.Endpoint(endpoint_name)  <-- Move this inside or ensure it's accessible

@api_view(['POST'])
@permission_classes([AllowAny])
@csrf_exempt
def generate_schedule_ai(request):
    user_text = request.data.get('user_text', '').strip()
    if not user_text:
        return JsonResponse({'error': 'Please provide user text.'}, status=400)

    try:
        aiplatform.init(project="vision-458010", location="us-west2") # Ensure initialized here too
        endpoint = aiplatform.Endpoint(endpoint_name="your-deployed-endpoint-name") # Initialize within the function

        prediction = endpoint.predict(instances=[{"content": user_text}]).predictions[0]
        extracted_info = {
            'day_of_week': int(prediction.get('day_of_week', 0)),
            'start_time': prediction.get('start_time', '00:00'),
            'end_time': prediction.get('end_time'),
            'event_name': prediction.get('event_name', '')
        }
        return JsonResponse(extracted_info, status=200)

    except Exception as e:
        return JsonResponse({'error': f'Error processing with AI: {str(e)}'}, status=500)

