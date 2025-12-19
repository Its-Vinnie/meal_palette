import 'package:flutter/material.dart';
import 'package:meal_palette/screen/profile_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _editProfileController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(),
                        ),
                      );
                    },
                    child: Icon(Icons.arrow_back_ios),
                  ),

                  SizedBox(width: 20),

                  Text("Edit Profile", style: AppTextStyles.pageHeadline),
                ],
              ),

              SizedBox(height: 20),

              CustomTextField(
                controller: _editProfileController,
                label: "Change Name",
                hint: "Enter new name",
                prefixIcon: Icons.person,
              ),

              SizedBox(height: 15),

              CustomTextField(
                controller: _editProfileController,
                label: "Change Email",
                hint: "Enter new email",
                prefixIcon: Icons.email_outlined,
              ),

              SizedBox(height: 20),

              Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: FilledButton(
                  onPressed: () {
                    //
                  },
                  child: Text("Update", style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
