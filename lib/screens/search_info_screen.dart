import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SearchInfoScreen extends StatefulWidget {
  const SearchInfoScreen({Key? key}) : super(key: key);

  @override
  _SearchInfoScreenState createState() => _SearchInfoScreenState();
}

class _SearchInfoScreenState extends State<SearchInfoScreen> {
  User? doctor = FirebaseAuth.instance.currentUser;
  String doctorName = "Loading...";
  String specialization = "Loading...";
  int numberOfPatients = 0;
  List<String> patientIds = [];
  List<Map<String, dynamic>> allPatientData = [];
  List<Map<String, dynamic>> filteredPatients = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDoctorInfo();
  }

  Future<void> fetchDoctorInfo() async {
    if (doctor == null) return;

    try {
      DatabaseReference doctorRef = FirebaseDatabase.instance.ref(
        'doctors/${doctor!.uid}',
      );
      DataSnapshot doctorSnapshot = await doctorRef.get();

      if (doctorSnapshot.exists) {
        Map<String, dynamic> doctorData = Map<String, dynamic>.from(
          doctorSnapshot.value as Map,
        );
        setState(() {
          doctorName = doctorData['name'] ?? "Unknown";
          specialization = doctorData['spec'] ?? "Not Available";
          patientIds = List<String>.from(doctorData['patients'] ?? []);
          numberOfPatients = patientIds.length;
        });

        fetchPatientData();
      }
    } catch (e) {
      setState(() {
        doctorName = "Error loading doctor data";
      });
      print("Error: $e");
    }
  }

  Future<void> fetchPatientData() async {
    try {
      for (String patientId in patientIds) {
        DatabaseReference patientRef = FirebaseDatabase.instance.ref(
          'patients/$patientId',
        );
        DataSnapshot patientSnapshot = await patientRef.get();

        if (patientSnapshot.exists) {
          Map<String, dynamic> patientData = Map<String, dynamic>.from(
            patientSnapshot.value as Map,
          );
          setState(() {
            allPatientData.add({...patientData, 'id': patientId});
          });
        }
      }
      filteredPatients = allPatientData;
    } catch (e) {
      print("Error fetching patient data: $e");
    }
  }

  void searchPatient(String query) {
    setState(() {
      filteredPatients =
          allPatientData.where((patient) {
            String name = patient['name']?.toLowerCase() ?? "";
            return name.contains(query.toLowerCase());
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Doctor Name: $doctorName",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "Specialization: $specialization",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "Number of Patients: $numberOfPatients",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchController,
              onChanged: searchPatient,
              decoration: InputDecoration(
                labelText: 'Search for a patient',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            filteredPatients.isEmpty
                ? const Text(
                  "No patients found",
                  style: TextStyle(color: Colors.red),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    var patient = filteredPatients[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text("Name: ${patient['name']}"),
                        subtitle: Text("Patient ID: ${patient['id']}"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PatientDetailsScreen(
                                    patientId: patient['id'],
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class PatientDetailsScreen extends StatelessWidget {
  final String patientId;

  const PatientDetailsScreen({Key? key, required this.patientId})
    : super(key: key);

  int calculateAge(String dob) {
    DateTime birthDate = DateTime.parse(dob);
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month &&
            currentDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String formatDateTime(String timestamp) {
    try {
      int timeInMilliseconds = int.parse(timestamp);
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timeInMilliseconds);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return "Invalid Timestamp";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: FutureBuilder<DataSnapshot>(
        future: FirebaseDatabase.instance.ref('patients/$patientId').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.value == null) {
            return const Center(child: Text("Patient data not found."));
          }

          Map<String, dynamic> patientData = Map<String, dynamic>.from(
            snapshot.data!.value as Map,
          );
          int age = calculateAge(patientData['dob'] ?? "0000-00-00");

          // Sorting logs in descending order of timestamp
          List<Map<String, dynamic>> logs = [];
          if (patientData.containsKey('logs')) {
            logs =
                patientData['logs'].values
                    .map<Map<String, dynamic>>(
                      (log) => Map<String, dynamic>.from(log),
                    )
                    .toList();
            logs.sort(
              (a, b) => int.parse(
                b['timestamp'],
              ).compareTo(int.parse(a['timestamp'])),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Name: ${patientData['name']}"),
                  Text("Age: $age"),
                  Text("Sex: ${patientData['sex'] ?? 'N/A'}"),
                  Text("Height: ${patientData['height'] ?? 'N/A'} cm"),
                  Text("Weight: ${patientData['weight'] ?? 'N/A'} kg"),
                  Text(
                    "Fitness Level: ${patientData['fitness_level'] ?? 'N/A'}",
                  ),
                  Text("Blood Type: ${patientData['blood_type'] ?? 'N/A'}"),
                  if (patientData.containsKey('health_data')) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Current Vitals:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Heart Rate: ${patientData['health_data']['heart_rate']} BPM",
                    ),
                    Text(
                      "Temperature: ${patientData['health_data']['temperature']} °C",
                    ),
                    Text("SpO2: ${patientData['health_data']['SpO2']}%"),
                  ],
                  if (logs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Patient Alert Logs :",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (var log in logs)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            (log['issues_detected'] as List<dynamic>).join(
                              ', ',
                            ),
                          ),
                          subtitle: Text(
                            "Heart Rate: ${log['heart_rate']} BPM, "
                            "Temperature: ${log['temperature']} °C, "
                            "SpO2: ${log['SpO2']}%\n"
                            "Timestamp: ${formatDateTime(log['timestamp'])}",
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
