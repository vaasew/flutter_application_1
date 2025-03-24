import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      print("Error fetching doctor data: $e");
    }
  }

  Future<void> fetchPatientData() async {
    try {
      allPatientData.clear();
      filteredPatients.clear();

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
            filteredPatients = List.from(allPatientData);
          });
        }
      }
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

  Future<void> updateDetectFlag(String patientId, bool value) async {
    try {
      await FirebaseDatabase.instance
          .ref('patients/$patientId/detect_flag')
          .set(value);
      print("Detect flag for $patientId updated to: $value");
      setState(() {
        final index = filteredPatients.indexWhere((p) => p['id'] == patientId);
        if (index != -1) {
          filteredPatients[index]['detect_flag'] = value;
        }
      });
    } catch (e) {
      print("Error updating detect flag: $e");
    }
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
                    bool detectFlag = patient['detect_flag'] ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text("Name: ${patient['name']}"),
                        subtitle: Text("Patient ID: ${patient['id']}"),
                        trailing: Switch(
                          value: detectFlag,
                          onChanged:
                              (value) => updateDetectFlag(patient['id'], value),
                          activeColor: Colors.green,
                        ),
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

// ----------------------------------------------------------
// Patient Details Screen
// ----------------------------------------------------------

class PatientDetailsScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailsScreen({Key? key, required this.patientId})
    : super(key: key);

  @override
  _PatientDetailsScreenState createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  Map<String, dynamic>? patientData;
  bool detectFlag = false;

  @override
  void initState() {
    super.initState();
    fetchPatientData();
  }

  Future<void> fetchPatientData() async {
    try {
      DatabaseReference patientRef = FirebaseDatabase.instance.ref(
        'patients/${widget.patientId}',
      );
      DataSnapshot snapshot = await patientRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        setState(() {
          patientData = Map<String, dynamic>.from(snapshot.value as Map);
          detectFlag = patientData?['detect_flag'] ?? false;
        });
      } else {
        print("Patient data not found.");
      }
    } catch (e) {
      print("Error fetching patient data: $e");
    }
  }

  void toggleDetectFlag(bool value) async {
    try {
      DatabaseReference patientRef = FirebaseDatabase.instance.ref(
        'patients/${widget.patientId}',
      );
      await patientRef.update({'detect_flag': value});
      setState(() {
        detectFlag = value;
      });
      print("Detect flag updated to: $value");
    } catch (e) {
      print("Error updating detect flag: $e");
    }
  }

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

  String formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp),
      );
      return "${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}";
    } catch (e) {
      print("Error formatting timestamp: $e");
      return "Invalid timestamp";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (patientData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    int age = calculateAge(patientData?['dob'] ?? "0000-00-00");

    // Extract current vitals
    Map<String, dynamic> currentVitals = Map<String, dynamic>.from(
      patientData?['health_data'] ?? {},
    );

    // Extract and sort logs in descending order
    List<Map<String, dynamic>> logs = [];
    if (patientData?['logs'] != null) {
      patientData!['logs'].forEach((key, value) {
        logs.add(Map<String, dynamic>.from(value));
      });
      logs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details'),
        actions: [
          Row(
            children: [
              const Text("Detect Flag"),
              Switch(value: detectFlag, onChanged: toggleDetectFlag),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${patientData?['name']}"),
            Text("Age: $age"),
            Text("Sex: ${patientData?['sex'] ?? 'N/A'}"),
            Text("Height: ${patientData?['height'] ?? 'N/A'} cm"),
            Text("Weight: ${patientData?['weight'] ?? 'N/A'} kg"),
            Text("Fitness Level: ${patientData?['fitness_level'] ?? 'N/A'}"),
            Text("Blood Type: ${patientData?['blood_type'] ?? 'N/A'}"),

            const SizedBox(height: 20),
            const Text(
              "Current Vitals",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text("Heart Rate: ${currentVitals['heart_rate'] ?? 'N/A'} bpm"),
            Text("Temperature: ${currentVitals['temperature'] ?? 'N/A'} °C"),
            Text("SpO2: ${currentVitals['SpO2'] ?? 'N/A'} %"),

            const SizedBox(height: 20),
            const Text(
              "Health Logs (Descending Order)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            logs.isEmpty
                ? const Text("No logs available.")
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    var log = logs[index];
                    String formattedTime = formatTimestamp(
                      log['timestamp'].toString(),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text("Time: $formattedTime"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Heart Rate: ${log['heart_rate']} bpm"),
                            Text("Temperature: ${log['temperature']} °C"),
                            Text("SpO2: ${log['SpO2']} %"),
                            if (log['issues_detected'] != null)
                              Text(
                                "Issues: ${log['issues_detected'].join(', ')}",
                              ),
                          ],
                        ),
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
