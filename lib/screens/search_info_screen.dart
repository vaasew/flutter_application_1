import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'patient_vitals_screen.dart';

class SearchInfoScreen extends StatefulWidget {
  const SearchInfoScreen({super.key});

  @override
  _SearchInfoScreenState createState() => _SearchInfoScreenState();
}

class _SearchInfoScreenState extends State<SearchInfoScreen> {
  User? doctor = FirebaseAuth.instance.currentUser;
  String doctorName = "";
  String doctorSpecialization = "";
  int numberOfPatients = 0;
  List<Map<String, dynamic>> patientsList = [];
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchDoctorInfo();
  }

  Future<void> fetchDoctorInfo() async {
    if (doctor == null) return;

    final doctorRef = FirebaseDatabase.instance.ref('doctors/${doctor!.uid}');
    final doctorSnapshot = await doctorRef.get();

    if (doctorSnapshot.exists) {
      final data = doctorSnapshot.value as Map<String, dynamic>;
      setState(() {
        doctorName = data['name'] ?? "Unknown";
        doctorSpecialization = data['spec'] ?? "Not specified";
        numberOfPatients = (data['patients'] as List<dynamic>?)?.length ?? 0;
      });

      // Fetch all patient data
      if (data['patients'] != null) {
        for (String patientId in data['patients']) {
          final patientRef = FirebaseDatabase.instance.ref(
            'patients/$patientId',
          );
          final patientSnapshot = await patientRef.get();
          if (patientSnapshot.exists) {
            final patientData = patientSnapshot.value as Map<String, dynamic>;
            patientsList.add({...patientData, 'id': patientId});
          }
        }
      }
    }
  }

  void searchPatients(String query) {
    setState(() {
      searchResults =
          patientsList
              .where(
                (patient) => (patient['name'] as String).toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
    });
  }

  void navigateToPatient(String patientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientVitalsScreen(patientId: patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Doctor Name: $doctorName",
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            "Specialization: $doctorSpecialization",
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            "Number of Patients: $numberOfPatients",
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search for a patient',
              border: OutlineInputBorder(),
            ),
            onChanged: searchPatients,
          ),
          const SizedBox(height: 20),
          searchResults.isEmpty
              ? const Text("No patients found")
              : ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final patient = searchResults[index];
                  return ListTile(
                    title: Text(patient['name']),
                    subtitle: Text("ID: ${patient['id']}"),
                    onTap: () => navigateToPatient(patient['id']),
                  );
                },
              ),
        ],
      ),
    );
  }
}
