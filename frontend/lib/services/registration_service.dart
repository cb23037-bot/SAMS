// import 'api_service.dart';

// class RegistrationService {
//   final ApiService _api;

//   RegistrationService(this._api);

//   /// Fetches the list of subjects available for the current semester.
//   /// 
//   /// Calls GET /api/subjects/available
//   Future<List<dynamic>> getAvailableSubjects() async {
//     final response = await _api.sendRequest(
//       method: 'GET',
//       path: '/subjects/available',
//     );
    
//     // Ensure the response is treated as a List
//     return response is List ? response : [];
//   }

//   /// Submits the registration for selected subjects.
//   /// 
//   /// Calls POST /api/subjects/register
//   Future<Map<String, dynamic>> submitRegistration(List<int> subjectIds) async {
//     final response = await _api.sendRequest(
//       method: 'POST',
//       path: '/subjects/register',
//       body: {'subject_ids': subjectIds},
//     );
    
//     return response as Map<String, dynamic>;
//   }

//   /// Checks if registration is currently open for the active semester.
//   /// 
//   /// Calls GET /api/registration/status
//   Future<bool> checkRegistrationStatus() async {
//     try {
//       final response = await _api.sendRequest(
//         method: 'GET',
//         path: '/registration/status',
//       );
      
//       // Returns true if the key exists and is true
//       return response['is_registration_open'] == true;
//     } catch (e) {
//       // Default to false if the request fails
//       return false;
//     }
//   }
// }