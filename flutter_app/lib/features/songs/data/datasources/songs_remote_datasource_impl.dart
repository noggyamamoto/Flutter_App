import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource.dart';

class SongsRemoteDatasourceImpl implements SongsRemoteDataSource{
  final FirebaseFirestore firestore;

  SongsRemoteDatasourceImpl(this.firestore);

  @override
  Future<List<Map<String, dynamic>>> getSongs() async {
    final snapshot = await firestore.collection('partituras').get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }
}